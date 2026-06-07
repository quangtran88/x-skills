#!/usr/bin/env bash
# meta-gate.sh — map an eval outcome + judge calibration to a final verdict.
# stdin: { raw_pass:bool, scorer:"judge"|"deterministic", kappa:<float|null>, calibrated:bool }
# env:   X_QA_KAPPA_FAIL (default 0.90), X_QA_KAPPA_WARN (default 0.85)
# stdout:{ verdict:"pass"|"fail", advisory:bool, uncalibrated:bool, reason }
# Bands (only when raw_pass is false and scorer is a judge):
#   kappa >= FAIL                 -> fail
#   WARN <= kappa < FAIL          -> advisory (verdict pass, advisory=true)
#   kappa < WARN OR uncalibrated  -> advisory + uncalibrated=true
set -euo pipefail
INPUT=$(cat)
KFAIL="${X_QA_KAPPA_FAIL:-0.90}"
KWARN="${X_QA_KAPPA_WARN:-0.85}"
jq -n --argjson d "$INPUT" --argjson kfail "$KFAIL" --argjson kwarn "$KWARN" '
  ($d.raw_pass) as $pass
  | ($d.scorer // "judge") as $scorer
  | ($d.calibrated // false) as $cal
  | ($d.kappa) as $k
  | if $pass then
      { verdict:"pass", advisory:false, uncalibrated:false, reason:"score >= threshold" }
    elif $scorer == "deterministic" then
      { verdict:"fail", advisory:false, uncalibrated:false, reason:"deterministic scorer below threshold" }
    elif ($cal and $k != null and $k >= $kfail) then
      { verdict:"fail", advisory:false, uncalibrated:false,
        reason:("judge calibrated kappa=" + ($k|tostring) + " >= " + ($kfail|tostring)) }
    elif ($cal and $k != null and $k >= $kwarn) then
      { verdict:"pass", advisory:true, uncalibrated:false,
        reason:("judge advisory: kappa=" + ($k|tostring) + " in [" + ($kwarn|tostring) + "," + ($kfail|tostring) + ") — would-fail downgraded to warn") }
    elif $cal then
      { verdict:"pass", advisory:true, uncalibrated:true,
        reason:("judge advisory: kappa=" + (($k // 0)|tostring) + " < " + ($kwarn|tostring) + " — below trust floor") }
    else
      { verdict:"pass", advisory:true, uncalibrated:true,
        reason:"judge uncalibrated (no gold set) — advisory only" }
    end'
