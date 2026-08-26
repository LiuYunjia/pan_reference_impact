## DNAnexus minimap2 mapping

Maps the fixed 20-SMRT-cell HG002 CCS subset to hs1 and hg15–hg38 using minimap2 2.31 with the map-hifi preset. Each job produces a sorted BAM, BAI, flagstat, checksums, provenance, and resolved-read manifest.

Requirements: authenticated DNAnexus CLI, jq, uploaded FASTQs, reference-index bundles, and the DNAnexus file IDs recorded in the TSV configurations.

Build the applet:
```
  dx build . --brief > applet-build.json
  APPLET_ID="$(jq -r '.id' applet-build.json)"
```

Launch all builds at high priority:
```
  bash 02-launch-dnanexus-minimap2.sh \
    "$APPLET_ID" \
    mem2_ssd1_v2_x32 \
    --submit \
    all \
    high
```
Outputs are written to:
```
  /results/minimap2/<build>/
```

`dnanexus-minimap2-hg002-authoritative-jobs.tsv` records the final completed job IDs and is not required when launching new jobs.
