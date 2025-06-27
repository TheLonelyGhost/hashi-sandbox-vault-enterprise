#!/usr/bin/env python3

import asyncio
from datetime import datetime, UTC
import json
import logging
import os
from typing import (
    Dict,
    Literal,
    List,
    Union,
)

from vault_auth import BaseVaultAuth, VaultAuthAppRole, VaultHeaders, HttpxAuth
from vault_event import _EventRouter, _NotifyHandler, VaultNotification

# from cloudevents.http import CloudEvent, from_dict as ce_from_dict
import httpx
import websockets.exceptions
from websockets.asyncio.client import connect as ws_connect


_VaultPath = str
_JsonType = Union[
    int,
    float,
    str,
    bool,
    Literal[None],
    List["_JsonType"],
    Dict[str, "_JsonType"],
]
_VaultResponseData = Dict[str, _JsonType]

log = logging.getLogger(__name__)

MIN_TO_REFRESH = 3 * 60  # 3 minutes
MAX_SLEEP = 5 * 60  # 5 minutes


async def renew_auth(auth: BaseVaultAuth):
    async with httpx.AsyncClient(http2=True) as http:
        while True:
            if not auth.token.is_valid:
                await auth.async_authn(http)
            elif auth.token.is_renewable:
                log.debug(f"{auth.token!r} is able to be renewed")
                await auth.async_renew(http)

            await asyncio.sleep(
                min(
                    [
                        MAX_SLEEP,
                        max(
                            [
                                auth.token.ttl - MIN_TO_REFRESH,
                                0,
                            ]
                        ),
                    ]
                )
            )


async def ws_listen(auth: BaseVaultAuth, http: httpx.AsyncClient):
    # resp = await http.get("/sys/leader")
    # leader_api_addr = resp.raise_for_status().json()["leader_address"]
    base_url = auth.vault_addr
    async for ws in ws_connect(
        uri=f"{base_url.replace('http', 'ws')}/v1/sys/events/subscribe/kv-v2/*?json=true",
        additional_headers=VaultHeaders(auth=auth),
    ):
        try:
            log.info("Starting websocket listener for KV events")
            async for msg in ws:
                if not msg:
                    continue
                elif isinstance(msg, bytes):
                    msg = msg.decode()
                await ws_process_message(msg, http)

        except websockets.exceptions.ConnectionClosed:
            log.info("Websocket connection crashed. Reconnecting...")
            continue


async def ws_process_message(msg: str, http: httpx.AsyncClient):
    try:
        obj = json.loads(msg)
    except json.decoder.JSONDecodeError:
        log.warning("Malformed notification. Was not JSON.")
        return
    notify = VaultNotification.from_dict(obj["data"])
    func: _NotifyHandler = ROUTER.get(notify.event_type, stub_handler)
    await func(notify, http)


async def periodically_write_secret(http: httpx.AsyncClient):
    while True:
        await asyncio.sleep(3)

        resp = await http.post(
            "/kv/my-thing/data/lorem",
            json={
                "data": {
                    "ipsum": "dolor",
                    "other": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:SZ"),
                }
            },
        )
        try:
            resp.raise_for_status()
        except httpx.HTTPStatusError as e:
            log.error(e)


async def main():
    log.setLevel(logging.DEBUG)
    auth = VaultAuthAppRole(
        role_id=os.environ["VAULT_AUTH_APPROLE_ROLE_ID"],
        secret_id=os.environ["VAULT_AUTH_APPROLE_SECRET_ID"],
    )
    await auth.async_authn()

    tasks = []

    # Background task to continue renewing as-needed
    tasks.append(asyncio.create_task(renew_auth(auth)))

    base_url = auth.vault_addr
    log.debug(repr(auth.token))
    async with httpx.AsyncClient(
        base_url=f"{base_url}/v1",
        headers={
            "Accept": "application/json",
        },
        auth=HttpxAuth(auth=auth),
        http2=True,
    ) as http:
        tasks.append(asyncio.create_task(ws_listen(auth, http)))
        tasks.append(asyncio.create_task(periodically_write_secret(http)))

        await asyncio.wait(tasks)


CacheLock = asyncio.Lock()
KvCache: Dict[_VaultPath, _VaultResponseData] = {}


async def stub_handler(*_) -> None: ...
async def kv_delete_handler(note: VaultNotification, _: httpx.AsyncClient) -> None:
    """When a deletion notification comes in, remove the value from cache"""
    if note.event_type not in [
        "kv-v2/data-delete",
        "kv-v2/delete",
        "kv-v2/destroy",
        "kv-v2/metadata-delete",
    ]:
        raise RuntimeError()

    kv_path = note.event.metadata["data_path"]
    async with CacheLock:
        if kv_path in KvCache:
            del KvCache[kv_path]
            log.info(
                f"Responding to deletion notification by removing {kv_path!r} from cache"
            )


async def kv_update_handler(note: VaultNotification, http: httpx.AsyncClient) -> None:
    """When an update notification comes in, retrieve the latest value and update the cache"""
    if note.event_type not in [
        "kv-v2/data-patch",
        "kv-v2/data-write",
        "kv-v2/metadata-patch",
        "kv-v2/metadata-write",
        "kv-v2/undelete",
    ]:
        raise RuntimeError()

    async with CacheLock:
        kv_path = note.event.metadata["data_path"]
        log.info(
            f"Responding to update notification by re-fetching {kv_path!r} from cache"
        )
        resp = await http.get(kv_path)
        obj = resp.raise_for_status().json()
        KvCache[kv_path] = obj["data"]


ROUTER: _EventRouter = {
    "kv-v2/data-delete": kv_delete_handler,
    "kv-v2/data-patch": kv_update_handler,
    "kv-v2/data-write": kv_update_handler,
    "kv-v2/delete": kv_delete_handler,
    "kv-v2/destroy": kv_delete_handler,
    "kv-v2/metadata-delete": kv_delete_handler,
    "kv-v2/metadata-patch": kv_update_handler,
    "kv-v2/metadata-write": kv_update_handler,
    "kv-v2/undelete": kv_update_handler,
}


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
