# hammer-sil22-24.ps1 -- SIL-22, SIL-23, SIL-24 coordinator
#
# This file stays as the stable entrypoint already referenced by scripts/api-hammer.ps1.
# It now composes focused modules so the SERP disturbance hammer stays readable,
# maintainable, and aligned with route-contract / DB-integrity goals.

Hammer-Section "SIL-22-24 TESTS (IMPACT RANKING, AFFECTED KEYWORDS, OPERATOR HINTS)"

. "$PSScriptRoot\serp-disturbances\shared.ps1"
. "$PSScriptRoot\serp-disturbances\impact-and-affected.ps1"
. "$PSScriptRoot\serp-disturbances\hints-and-contract.ps1"
