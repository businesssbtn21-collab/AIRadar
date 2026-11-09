#!/bin/sh
# モード・職種の判定スクリプトを、Shared のモデルと一緒にコンパイルして実行する。
set -e
cd "$(dirname "$0")/../.."
out="${TMPDIR:-/tmp}/airadar_curation_check"
sources="Shared/AIServiceItem.swift tools/curation_check/main.swift"
for f in Shared/Profession.swift Shared/SharedStore.swift Shared/FeedMode.swift Shared/FeedSync.swift Shared/ChinaStorefrontPolicy.swift AIRadar/Services/ReviewPrompt.swift AIRadar/Services/LegacyPurchasePolicy.swift AIRadar/Services/OnboardingPolicy.swift AIRadar/Services/SmartSearch.swift; do
    [ -f "$f" ] && sources="$sources $f"
done
swiftc -o "$out" $sources
"$out"
