#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_dir="$root/tools/aligners"
src_dir="$root/tools/src"
threads="${SLURM_CPUS_PER_TASK:-8}"

mkdir -p "$root/tools" "$src_dir" "$root/artifacts/manifests"

packages=(minimap2=2.31 ngmlr=0.2.7 lra=1.3.7.2 winnowmap=2.03 meryl=1.4.2 curl unzip)
if [[ -d "$env_dir/conda-meta" ]]; then
    mamba install --yes --force-reinstall --prefix "$env_dir" \
        --channel conda-forge --channel bioconda "${packages[@]}"
else
    mamba create --yes --prefix "$env_dir" --channel conda-forge --channel bioconda \
        "${packages[@]}"
fi

archive="$src_dir/minibwa-v0.6.tar.gz"
curl --fail --location --retry 5 --retry-delay 10 \
    https://github.com/lh3/minibwa/archive/refs/tags/v0.6.tar.gz \
    --output "${archive}.part"
mv "${archive}.part" "$archive"
tar -xzf "$archive" -C "$src_dir"
make -C "$src_dir/minibwa-0.6" -j "$threads"
install -m 0755 "$src_dir/minibwa-0.6/minibwa" "$env_dir/bin/minibwa"

for executable in minimap2 minibwa ngmlr lra winnowmap meryl; do
    if [[ ! -x "$env_dir/bin/$executable" ]]; then
        echo "Missing executable: $env_dir/bin/$executable" >&2
        exit 1
    fi
    if ldd "$env_dir/bin/$executable" 2>&1 | grep -q 'not found'; then
        echo "Unresolved shared library for $executable:" >&2
        ldd "$env_dir/bin/$executable" >&2
        exit 1
    fi
done

{
    printf 'tool\trequested_version\tversion_output\n'
    printf 'minimap2\t2.31\t%s\n' "$("$env_dir/bin/minimap2" --version 2>&1 | head -n 1)"
    printf 'minibwa\t0.6\t%s\n' "$("$env_dir/bin/minibwa" 2>&1 | head -n 1 || true)"
    printf 'ngmlr\t0.2.7\t%s\n' "$("$env_dir/bin/ngmlr" --version 2>&1 | head -n 1 || true)"
    printf 'lra\t1.3.7.2\t%s\n' "$("$env_dir/bin/lra" --version 2>&1 | head -n 1 || true)"
    printf 'winnowmap\t2.03\t%s\n' "$("$env_dir/bin/winnowmap" --version 2>&1 | head -n 1 || true)"
    printf 'meryl\t1.4.2\t%s\n' "$("$env_dir/bin/meryl" --version 2>&1 | head -n 1)"
} > "$root/tools/versions.tsv"

printf 'complete\n' > "$root/tools/.complete"
