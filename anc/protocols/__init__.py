"""Vendor protocols, by family name (the names used in components/Anc.js)."""

from .apple import Apple
from .sony import Sony

FAMILIES = {
    "apple": Apple,
    "sony": Sony,
}
