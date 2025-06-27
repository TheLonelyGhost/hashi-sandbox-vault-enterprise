import asyncio
import os
import logging
import math
import threading
from datetime import UTC, datetime, timedelta
from typing import (
    AsyncGenerator,
    Dict,
    Generator,
    Iterable,
    List,
    Literal,
    Optional,
    Union,
    cast,
)

import httpx

_JsonType = Union[
    Literal[None],
    bool,
    float,
    int,
    str,
    List["_JsonType"],
    Dict[str, "_JsonType"],
]

DEFAULT_VAULT_ADDR = os.environ.get("VAULT_ADDR", "https://127.0.0.1:8200")
VAULT_TTL_OVERLAP = timedelta(minutes=2)
VAULT_TTL_EXTEND_BY = "300s"

log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)


class VaultToken:
    _token: str
    _expiry: Optional[datetime]

    def __init__(self, token: str, expiry: Optional[datetime] = None) -> None:
        self._token = token
        self._expiry = expiry

    def __str__(self) -> str:
        return self._token

    def __repr__(self) -> str:
        return f"VaultToken({self._token[0:6]}<redacted>{self._token[-4:]} [expires: {self.expiry}])"

    def update_from(self, token: "VaultToken"):
        self._token = token._token
        self._expiry = token._expiry

    @property
    def is_valid(self) -> bool:
        if not self._token:
            return False
        if not self._expiry:
            return True
        delta = self._expiry - datetime.now(UTC)
        if delta < timedelta(seconds=1):
            # Is less than 1 second until expiry (or is already expired)
            return False
        return True

    @property
    def is_renewable(self) -> bool:
        if not self._token:
            return False
        if not self._expiry:
            return False
        delta = self._expiry - datetime.now(UTC)
        if delta > VAULT_TTL_OVERLAP:
            # Lots of validity left, don't renew because it would be wasteful
            return False
        return True

    @property
    def expiry(self) -> str:
        if not self._expiry:
            return "never"
        else:
            return self._expiry.strftime("%Y-%m-%dT%H:%M:%SZ")

    @property
    def ttl(self) -> int:
        if not self._expiry:
            return -1

        delta = self._expiry - datetime.now(UTC)
        return math.ceil(delta.total_seconds())

    @classmethod
    def from_auth_response(cls, body: Dict[str, _JsonType]):
        auth: Dict[str, _JsonType] = cast(Dict[str, _JsonType], body["auth"])
        lease_duration: int = cast(int, auth["lease_duration"])
        token: str = cast(str, auth["client_token"])

        expiry_delta = timedelta(seconds=lease_duration)
        expiry = datetime.now(UTC) + expiry_delta
        return cls(token=token, expiry=expiry)


class BaseVaultAuth:
    _token: VaultToken
    vault_addr: str

    def __init__(self, vault_addr: str = DEFAULT_VAULT_ADDR) -> None:
        self.vault_addr = vault_addr
        self._token = VaultToken("")

    async def async_renew(self, http: Optional[httpx.AsyncClient] = None):
        if http is None:
            async with httpx.AsyncClient(http2=True) as http:
                await self._async_renew(http)
        else:
            await self._async_renew(http)

    async def _async_renew(self, http: httpx.AsyncClient):
        resp = await http.post(
            f"{self.vault_addr}/v1/auth/token/renew-self",
            headers={
                "Accept": "application/json",
                "X-Vault-Request": "true",
                "X-Vault-Token": str(self._token),
            },
            json={"increment": VAULT_TTL_EXTEND_BY},
        )
        obj = resp.raise_for_status().json()
        expiry_delta = timedelta(seconds=obj["auth"]["lease_duration"])
        if expiry_delta < VAULT_TTL_OVERLAP:
            log.warning(
                "Renewal did not add enough time to the token TTL, so reauthenticating instead."
            )
            try:
                await self.async_authn()
                return
            except NotImplementedError:
                ...

        self._token.update_from(VaultToken.from_auth_response(obj))

    def renew(self, http: Optional[httpx.Client] = None):
        if http is None:
            with httpx.Client(http2=True) as http:
                self._renew(http)
        else:
            self._renew(http)

    def _renew(self, http: httpx.Client):
        resp = http.post(
            f"{self.vault_addr}/v1/auth/token/renew-self",
            headers={
                "Accept": "application/json",
                "X-Vault-Request": "true",
                "X-Vault-Token": str(self._token),
            },
            json={"increment": VAULT_TTL_EXTEND_BY},
        )
        obj = resp.raise_for_status().json()
        expiry_delta = timedelta(seconds=obj["auth"]["lease_duration"])
        if expiry_delta < VAULT_TTL_OVERLAP:
            log.warning(
                "Renewal did not add enough time to the token TTL, so reauthenticating instead."
            )
            try:
                self._authn(http)
                return
            except NotImplementedError:
                ...

        self._token.update_from(VaultToken.from_auth_response(obj))

    async def _async_authn(self, http: httpx.AsyncClient):
        raise NotImplementedError

    async def async_authn(self, http: Optional[httpx.AsyncClient] = None):
        if not http:
            async with httpx.AsyncClient(http2=True) as http:
                await self._async_authn(http)
        else:
            await self._async_authn(http)

    def _authn(self, http: httpx.Client):
        raise NotImplementedError

    def authn(self, http: Optional[httpx.Client] = None):
        if not http:
            with httpx.Client(http2=True) as http:
                self._authn(http)
        else:
            self._authn(http)

    @property
    def token(self) -> VaultToken:
        return self._token

    @token.setter
    def token(self, _: VaultToken) -> None:
        raise NotImplementedError

    @token.deleter
    def token(self) -> None:
        raise NotImplementedError


class VaultHeaders:
    def __init__(self, auth: BaseVaultAuth, always_authed: bool = False) -> None:
        self._headers: Dict[str, str] = {
            "Accept": "application/json",
            "X-Vault-Request": "true",
        }
        self._auth = auth
        self._always_authed = always_authed

    def keys(self) -> Iterable[str]:
        return list(self._headers.keys()) + ["X-Vault-Token"]

    def __getitem__(self, key: str) -> str:
        if key.casefold() != "X-Vault-Token".casefold():
            return self._headers[key]

        if not self._auth.token.is_valid:
            self._auth.authn()
        elif self._auth.token.is_renewable:
            self._auth.renew()

        return str(self._auth.token)


class HttpxAuth(httpx.Auth):
    def __init__(self, auth: BaseVaultAuth) -> None:
        self._sync_lock = threading.RLock()
        self._async_lock = asyncio.Lock()
        self._auth = auth

    async def async_auth_flow(
        self,
        request: httpx.Request,
    ) -> AsyncGenerator[httpx.Request, httpx.Response]:
        if not self._auth.token.is_valid:
            async with self._async_lock:
                await self._auth.async_authn()
        elif self._auth.token.is_renewable:
            async with self._async_lock:
                await self._auth.async_renew()

        log.debug(repr(self._auth.token))
        request.headers["X-Vault-Token"] = str(self._auth.token)
        yield request

    def sync_auth_flow(
        self,
        request: httpx.Request,
    ) -> Generator[httpx.Request, httpx.Response, None]:
        if not self._auth.token.is_valid:
            with self._sync_lock:
                self._auth.authn()
        elif self._auth.token.is_renewable:
            with self._sync_lock:
                self._auth.renew()

        log.debug(repr(self._auth.token))
        request.headers["X-Vault-Token"] = str(self._auth.token)
        yield request


class VaultAuthAppRole(BaseVaultAuth):
    role_id: str
    secret_id: str
    mount_path: str

    def __init__(
        self,
        role_id: str,
        secret_id: str,
        mount_path: str = "auth/approle",
        *args,
        **kwargs,
    ) -> None:
        super(VaultAuthAppRole, self).__init__(*args, **kwargs)
        self.role_id = role_id
        self.secret_id = secret_id
        self.mount_path = mount_path

    def _authn(self, http: httpx.Client):
        resp = http.post(
            f"{self.vault_addr}/v1/{self.mount_path}/login",
            headers={
                "Accept": "application/json",
                "X-Vault-Request": "true",
            },
            json={
                "role_id": self.role_id,
                "secret_id": self.secret_id,
            },
        )
        obj = resp.raise_for_status().json()
        self._token.update_from(VaultToken.from_auth_response(obj))

    async def _async_authn(self, http: httpx.AsyncClient):
        resp = await http.post(
            f"{self.vault_addr}/v1/{self.mount_path}/login",
            headers={
                "Accept": "application/json",
                "X-Vault-Request": "true",
            },
            json={
                "role_id": self.role_id,
                "secret_id": self.secret_id,
            },
        )
        obj = resp.raise_for_status().json()
        self._token.update_from(VaultToken.from_auth_response(obj))
