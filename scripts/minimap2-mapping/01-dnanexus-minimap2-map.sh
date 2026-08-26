#!/usr/bin/env bash

main() {
    set -euo pipefail
    export LC_ALL=C

    case "$build" in
        hg15|hg16|hg17|hg18|hg19|hg38|hs1) ;;
        *) echo "Unsupported build: $build" >&2; return 2 ;;
    esac

    [[ "$mapper_threads" =~ ^[1-9][0-9]*$ ]]
    [[ "$sort_threads" =~ ^[1-9][0-9]*$ ]]
    [[ "$sort_memory_gib" =~ ^[1-9][0-9]*$ ]]
    if (( mapper_threads + sort_threads + 1 > $(nproc) )); then
        echo "Thread request exceeds worker capacity" >&2
        return 2
    fi

    dx-download-all-inputs --parallel

    work="$HOME/work"
    mkdir -p "$work/index" "$work/tmp"
    cd "$work"

    curl --fail --location --silent --show-error \
        https://micro.mamba.pm/api/micromamba/linux-64/latest \
        | tar -xj -C "$work" bin/micromamba
    "$work/bin/micromamba" create -y -p "$work/env" \
        -c conda-forge -c bioconda \
        minimap2=2.31 samtools=1.24 zstd
    export PATH="$work/env/bin:$PATH"
    [[ "$(minimap2 --version)" == "2.31-r1302" || "$(minimap2 --version)" == "2.31" ]]

    mapfile -d '' -t read_paths < <(find "$HOME/in/reads" -type f -print0 | sort -z)
    [[ ${#read_paths[@]} -eq 20 ]] || {
        echo "Expected exactly 20 selected read files; found ${#read_paths[@]}" >&2
        return 2
    }

    awk 'NF {sub(/\r$/, ""); print}' "$subset_manifest_path" | sort -u > expected.names
    printf '%s\n' "${read_paths[@]##*/}" | sort -u > observed.names
    if ! cmp -s expected.names observed.names; then
        echo "Read inputs do not exactly match the authoritative subset" >&2
        diff -u expected.names observed.names >&2 || true
        return 2
    fi

    printf 'name\tsize_bytes\n' > "HG002.${build}.minimap2.reads.tsv"
    for read_path in "${read_paths[@]}"; do
        printf '%s\t%s\n' "${read_path##*/}" "$(stat -c %s "$read_path")" \
            >> "HG002.${build}.minimap2.reads.tsv"
    done

    observed_index_sha256="$(sha256sum "$index_bundle_path" | awk '{print $1}')"
    [[ "$observed_index_sha256" == "$expected_index_sha256" ]] || {
        echo "Index archive checksum mismatch" >&2
        return 2
    }
    tar --use-compress-program=unzstd -xf "$index_bundle_path" -C "$work/index"
    mapfile -t mmi_paths < <(find "$work/index" -type f -name "${build}.map-hifi.mmi" -print)
    [[ ${#mmi_paths[@]} -eq 1 ]] || {
        echo "Expected one ${build}.map-hifi.mmi; found ${#mmi_paths[@]}" >&2
        return 2
    }
    mmi="${mmi_paths[0]}"

    bam="HG002.${build}.minimap2.map-hifi.bam"
    flagstat="HG002.${build}.minimap2.map-hifi.flagstat.txt"
    provenance="HG002.${build}.minimap2.map-hifi.provenance.txt"
    checksum="HG002.${build}.minimap2.map-hifi.sha256"

    minimap2 -ax map-hifi -t "$mapper_threads" -Y \
        -R "@RG\\tID:${build}_mm2_hifi\\tSM:HG002\\tPL:PACBIO\\tLB:CCS_15kb_15x_cells" \
        "$mmi" "${read_paths[@]}" \
        | samtools sort -@ "$sort_threads" -m "${sort_memory_gib}G" \
            -T "$work/tmp/sort" -o "$bam" -
    samtools quickcheck -v "$bam"
    samtools index -@ "$mapper_threads" "$bam"
    samtools flagstat -@ "$mapper_threads" "$bam" > "$flagstat"
    sha256sum "$bam" "${bam}.bai" > "$checksum"

    {
        printf 'sample=HG002\n'
        printf 'build=%s\n' "$build"
        printf 'preset=map-hifi\n'
        printf 'subset_strategy=fixed_SMRT_cells\n'
        printf 'subset_manifest=%s\n' "$subset_manifest_name"
        printf 'read_files=%s\n' "${#read_paths[@]}"
        awk 'NR>1 {bytes+=$2} END {printf "read_bytes=%d\n", bytes}' \
            "HG002.${build}.minimap2.reads.tsv"
        printf 'index_archive=%s\n' "$index_bundle_name"
        printf 'index_archive_sha256=%s\n' "$observed_index_sha256"
        printf 'mapper_threads=%s\n' "$mapper_threads"
        printf 'sort_threads=%s\n' "$sort_threads"
        printf 'sort_memory_gib_per_thread=%s\n' "$sort_memory_gib"
        printf 'minimap2=%s\n' "$(minimap2 --version)"
        printf 'samtools=%s\n' "$(samtools --version | head -n 1)"
        printf 'command=minimap2 -ax map-hifi -Y | samtools sort\n'
        printf 'completed_utc=%s\n' "$(date -u +%FT%TZ)"
    } > "$provenance"

    bam_id="$(dx upload "$bam" --brief)"
    bai_id="$(dx upload "${bam}.bai" --brief)"
    flagstat_id="$(dx upload "$flagstat" --brief)"
    checksum_id="$(dx upload "$checksum" --brief)"
    provenance_id="$(dx upload "$provenance" --brief)"
    subset_id="$(dx upload "HG002.${build}.minimap2.reads.tsv" --brief)"

    dx-jobutil-add-output bam "$bam_id" --class=file
    dx-jobutil-add-output bai "$bai_id" --class=file
    dx-jobutil-add-output flagstat "$flagstat_id" --class=file
    dx-jobutil-add-output checksum "$checksum_id" --class=file
    dx-jobutil-add-output provenance "$provenance_id" --class=file
    dx-jobutil-add-output resolved_subset "$subset_id" --class=file
}
