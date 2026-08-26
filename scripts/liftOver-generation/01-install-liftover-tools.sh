#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_dir="$root/tools/liftover"
packages=(minimap2=2.31 transanno=0.4.5 samtools pigz)

mkdir -p "$root/tools" "$root/artifacts/manifests"
if [[ -d "$env_dir/conda-meta" ]]; then
    mamba install --yes --force-reinstall --prefix "$env_dir" \
        --channel conda-forge --channel bioconda "${packages[@]}"
else
    mamba create --yes --prefix "$env_dir" --channel conda-forge --channel bioconda \
        "${packages[@]}"
fi

for executable in minimap2 transanno samtools pigz; do
    if [[ ! -x "$env_dir/bin/$executable" ]]; then
        echo "Missing executable: $env_dir/bin/$executable" >&2
        exit 1
    fi
    if ldd "$env_dir/bin/$executable" 2>&1 | grep -q 'not found'; then
        echo "Unresolved shared library for $executable" >&2
        ldd "$env_dir/bin/$executable" >&2
        exit 1
    fi
done

smoke_dir="$(mktemp -d "${SLURM_TMPDIR:-/tmp}/liftover-tools.XXXXXX")"
trap 'rm -rf "$smoke_dir"' EXIT
{
    printf '>sourceChr\n'
    for _ in {1..64}; do printf 'ACGTACGTTGCAACGATCGATGCTAGCTACGATGCTAGCATCGATCGTAGCTAGCATGCAACGT\n'; done
} > "$smoke_dir/source.fa"
{
    printf '>targetChr\n'
    for _ in {1..64}; do printf 'ACGTACGTTGCAACGATCGATGCTAGCTACGATGCTAGCATCGATCGTAGCTAGCATGCAACGT\n'; done
} > "$smoke_dir/target.fa"
"$env_dir/bin/minimap2" -cx asm5 --cs "$smoke_dir/target.fa" "$smoke_dir/source.fa" \
    > "$smoke_dir/test.paf"
"$env_dir/bin/transanno" minimap2chain "$smoke_dir/test.paf" \
    --output "$smoke_dir/test.chain"
awk '$1=="chain" && $3=="sourceChr" && $8=="targetChr" {ok=1}
     END {exit !ok}' "$smoke_dir/test.chain"

{
    printf 'tool\trequested_version\tversion_output\n'
    printf 'minimap2\t2.31\t%s\n' "$("$env_dir/bin/minimap2" --version 2>&1 | head -n 1)"
    printf 'transanno\t0.4.5\t%s\n' "$("$env_dir/bin/transanno" --version 2>&1 | head -n 1)"
    printf 'samtools\tBioConda current\t%s\n' "$("$env_dir/bin/samtools" --version | head -n 1)"
    printf 'pigz\tBioConda current\t%s\n' "$("$env_dir/bin/pigz" --version 2>&1 | head -n 1)"
} > "$root/tools/liftover-versions.tsv"

printf 'complete\n' > "$root/tools/liftover.complete"
