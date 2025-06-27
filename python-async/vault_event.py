import dataclasses
from typing import (
    Any,
    Callable,
    Coroutine,
    Dict,
    Literal,
    Union,
)

import httpx

_KvEventType = Union[
    Literal["kv-v2/data-delete"],
    Literal["kv-v2/data-patch"],
    Literal["kv-v2/data-write"],
    Literal["kv-v2/delete"],
    Literal["kv-v2/destroy"],
    Literal["kv-v2/metadata-delete"],
    Literal["kv-v2/metadata-patch"],
    Literal["kv-v2/metadata-write"],
    Literal["kv-v2/undelete"],
]
_DatabaseEventType = Union[
    Literal["database/config-delete"],
    Literal["database/config-write"],
    Literal["database/creds-create"],
    Literal["database/reload"],
    Literal["database/reload-connection"],
    Literal["database/reload-connection-fail"],
    Literal["database/reset"],
    Literal["database/role-create"],
    Literal["database/role-delete"],
    Literal["database/role-update"],
    Literal["database/root-rotate-fail"],
    Literal["database/root-rotate"],
    Literal["database/rotate-fail"],
    Literal["database/rotate"],
    Literal["database/static-creds-create-fail"],
    Literal["database/static-creds-create"],
    Literal["database/static-role-create"],
    Literal["database/static-role-delete"],
    Literal["database/static-update"],
]
_EventType = Union[_KvEventType, _DatabaseEventType]
_NotifyHandler = Callable[["VaultNotification", httpx.AsyncClient], Coroutine]
_EventRouter = Dict[_EventType, _NotifyHandler]


@dataclasses.dataclass
class VaultNotification:
    @dataclasses.dataclass
    class PluginInfo:
        mount_class: Union[Literal["secret"], Literal["auth"]]
        mount_accessor: str = ""
        mount_path: str = ""
        plugin: str = ""
        version: str = ""

    @dataclasses.dataclass
    class Event:
        id: str
        metadata: Dict[str, Any]

    event: Event
    event_type: _EventType
    plugin_info: PluginInfo

    @classmethod
    def from_dict(cls, obj) -> "VaultNotification":
        return cls(
            event=cls.Event(**obj["event"]),
            event_type=obj["event_type"],
            plugin_info=cls.PluginInfo(**obj["plugin_info"]),
        )
