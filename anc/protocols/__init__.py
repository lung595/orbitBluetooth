"""Vendor protocols, by family name (the names used in components/Anc.js)."""

from .apple import Apple
from .bose import Bose
from .earfun import EarFun
from .haylou import Haylou
from .huawei import Huawei
from .moondrop import Moondrop
from .nothing import Nothing
from .onemore import OneMore
from .oppo import Oppo
from .samsung import Samsung
from .sony import Sony
from .soundcore import Soundcore
from .xiaomi import Xiaomi

FAMILIES = {
    "apple": Apple,
    "bose": Bose,
    "earfun": EarFun,
    "haylou": Haylou,
    "huawei": Huawei,
    "moondrop": Moondrop,
    "nothing": Nothing,
    "onemore": OneMore,
    "oppo": Oppo,
    "samsung": Samsung,
    "sony": Sony,
    "soundcore": Soundcore,
    "xiaomi": Xiaomi,
}
