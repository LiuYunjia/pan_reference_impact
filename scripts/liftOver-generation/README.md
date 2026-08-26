## liftOver generation

Generates directed pairwise liftOver chains between hs1, hg38, hg19, hg18, hg17, hg16, and hg15. The 42 source–target combinations are defined in liftover-pairs.tsv.

Requirements: completed reference FASTAs, SLURM, minimap2 2.31, transanno 0.4.5, samtools, and pigz.

Submit the complete workflow:
```
  bash 05-submit-liftover-jobs.sh
```
Each pair is aligned with `minimap2 asm5 --cs` and converted to UCSC chain format. Outputs are written under:
```
  liftover/references/<build>/
  liftover/chains/<source>/<target>/
  artifacts/
  logs/
  state/
```
Each pair includes a compressed PAF, compressed chain, checksums, provenance, and summary statistics.
No SLURM partition is specified; use your cluster default or add one locally.
