function Get-SerpDisturbanceNoteProps($obj) {
    return @($obj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
}

function Compare-SerpDisturbanceStringArray($actual, $expected) {
    if (@($actual).Count -ne @($expected).Count) { return $false }
    for ($i = 0; $i -lt @($expected).Count; $i++) {
        if ($actual[$i] -ne $expected[$i]) { return $false }
    }
    return $true
}

$script:SerpDisturbanceBase = "/api/seo/serp-disturbances"
$script:SerpDisturbanceValidDrivers = @(
    "ai_overview_expansion",
    "feature_regime_shift",
    "competitor_dominance_shift",
    "intent_reclassification",
    "algorithm_shift",
    "unknown"
)
$script:SerpDisturbanceValidPriority = @("high", "medium", "low")
$script:SerpDisturbanceValidHintTypes = @(
    "review_ai_overview_keywords",
    "inspect_feature_transitions",
    "inspect_rank_turbulence",
    "inspect_domain_dominance",
    "inspect_intent_shift",
    "monitor_mixed_disturbance"
)
