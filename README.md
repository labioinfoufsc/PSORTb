# PSortb Docker Wrapper

This repository provides a **Docker container** that wraps the **PSORTb** program for bacterial protein subcellular localization prediction.  

PSORTb is available at [https://psort.org/psortb/](https://psort.org/psortb/).

PSORTb binaries are available at [https://github.com/brinkmanlab/psortb_commandline_docker](https://github.com/brinkmanlab/psortb_commandline_docker).

---

## Features

- Run PSORTb easily without manual installation.  
- Predict subcellular localization for bacterial proteins.  
- Input/output handled via mounted directories for easy access.
---

## Installation

Clone this repository:

```bash
git clone https://github.com/labioinfoufsc/PSORTb.git
```

Build the Docker image from scratch (optional; image also available on [Docker Hub](https://hub.docker.com/r/bioinfoufsc/psortb)):

```bash
docker build -t bioinfoufsc/psortb -f PSORTb/Dockerfile PSORTb/ 
```

---

## Usage

### Run PSORTb for gram positive bacterial proteins
See the params:
```
docker run --rm bioinfoufsc/psortb -h
```


Run the first 100 proteins of the [Clostridium botulinum proteome](https://www.uniprot.org/proteomes/UP000001986):

```bash
docker run --rm -v ${PWD}/PSORTb:/data/ bioinfoufsc/psortb -p -o terse -i /data/examples/gram_positive.fasta -r /data/examples/gram_positive.txt
```

### Run PSORTb for gram negative bacterial proteins

Run the first 100 proteins of the [Borreliella burgdorferi  proteome](https://www.uniprot.org/proteomes/UP000001807):

```bash
docker run --rm -v ${PWD}/PSORTb:/data/ bioinfoufsc/psortb -n -o terse -i /data/examples/gram_negative.fasta -r /data/examples/gram_negative.txt
```

**Notes:**

- `${PWD}/PSORTb` mounts your local PSORTb directory to `/data/` inside the container.  
- Input FASTA files should be placed in `/data/examples/`.  
- Output results will be saved in `/data/examples/`.

---

## Citation

If you use PSORTb in your work, please cite:

> **PSORTb v3.0**  
> N.Y. Yu, J.R. Wagner, M.R. Laird, G. Melli, S. Rey, R. Lo, P. Dao, S.C. Sahinalp, M. Ester, L.J. Foster, F.S.L. Brinkman (2010).  
> *PSORTb 3.0: Improved protein subcellular localization prediction with refined localization subcategories and predictive capabilities for all prokaryotes.*  
> **Bioinformatics**, 26(13): 1608–1615.  
> [https://doi.org/10.1093/bioinformatics/btq249](https://doi.org/10.1093/bioinformatics/btq249)

---

## Notes

- The Docker image bundles PSORTb for Linux and sets up the environment automatically.  
- Ensure your input FASTA files exist in the directory mounted to `/data/`.  
- Output files will be accessible on your host system through the same mounted directory.  
- This wrapper simplifies running PSORTb without installing Perl, Bioperl, or other dependencies manually.
