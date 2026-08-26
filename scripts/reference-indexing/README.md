## Reference indexing

Builds reference indexes for hs1, hg38, hg19, hg18, hg17, hg16, and hg15 using minimap2, minibwa, NGMLR, LRA, and Winnowmap.

Requirements: SLURM, Bash, mamba, curl, gzip, unzip, make, and a C compiler.

Submit the complete dependency-controlled workflow:
```
bash 05-submit-index-jobs.sh
```
The workflow downloads references, installs pinned tools, builds indexes, and creates a final manifest. Outputs are written under:
```
  references/<build>/
  indexes/<build>/<tool>/
  artifacts/
  logs/
  state/
```
Technology-specific indexes include ONT, PacBio CCS/HiFi, and PacBio CLR where supported. Minibwa indexes are technology-independent.
No SLURM partition is specified; use your cluster default or add an appropriate partition locally.
