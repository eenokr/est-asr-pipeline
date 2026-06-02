# ASR pipeline for Estonian speech recognition

This repository contains two separate Nextflow pipelines:

- `transcribe.nf` is the default CPU-only Kaldi pipeline.
- `transcribe-whisper-gpu.nf` is a Whisper/CUDA pipeline and requires an NVIDIA GPU.

The pipelines intentionally use separate entrypoints, configs, and Dockerfiles because their runtime dependencies are different.

## Installation

Install Java and Nextflow. Nextflow 23.0.0 or later is required.

    wget -qO- https://get.nextflow.io | bash
    chmod +x nextflow
    mkdir -p $HOME/.local/bin/
    mv nextflow $HOME/.local/bin/

Docker is recommended for both pipelines.

## CPU/Kaldi Pipeline

Pull the CPU image:

    docker pull alumae/est-asr-pipeline:0.1.4

Run the default CPU pipeline:

    nextflow run transcribe.nf --in /path/to/audio.mp3

On machines with limited RAM, run serially with one CPU and a Docker memory cap:

    nextflow run transcribe.nf -profile lowmem --in /path/to/audio.mp3

By default, results are written to `results/<audio-basename>/`:

    result.ctm  result.json  result.srt  result.trs  result.with-compounds.ctm  result.txt

The CPU pipeline writes plain transcript text to `result.txt`.

## Whisper/CUDA Pipeline

The Whisper pipeline requires an NVIDIA GPU, CUDA-compatible drivers, and the NVIDIA container runtime when using Docker.

Pull the GPU image:

    docker pull europe-north1-docker.pkg.dev/speech2text-218910/repo/est-asr-pipeline:1.1b

Run the Whisper pipeline:

    nextflow -C nextflow.whisper-gpu.config run transcribe-whisper-gpu.nf -profile docker --in /path/to/audio.mp3

For SGE:

    nextflow -C nextflow.whisper-gpu.config run transcribe-whisper-gpu.nf -profile docker,sge --in /path/to/audio.mp3

For SLURM:

    nextflow -C nextflow.whisper-gpu.config run transcribe-whisper-gpu.nf -profile docker,slurm --in /path/to/audio.mp3

By default, Whisper results are written to `results/`.

The Whisper pipeline writes speaker-prefixed transcript lines to `result.txt`.

## Parameters

Common parameters:

- `--in <filename>`: audio or video file to transcribe.
- `--out_dir <path>`: output directory.
- `--do_speaker_id true|false`: include speaker identification.
- `--do_language_id true|false`: filter non-Estonian speech segments.

CPU-only parameter:

- `--do_punctuation true|false`: run punctuation restoration.

Whisper-only parameter:

- `--in_file_list <filename>`: file containing input paths, one per line.

## Configuration

CPU/Kaldi configuration lives in `nextflow.config`.

Whisper/CUDA configuration lives in `nextflow.whisper-gpu.config`.

The Dockerfiles are separate:

- `Dockerfile`: CPU/Kaldi image recipe.
- `Dockerfile.whisper-gpu`: Whisper/CUDA image recipe.

## Nextflow Options

Useful standard Nextflow options:

- `-with-report`: write an HTML execution report.
- `-with-trace`: write a machine-readable execution trace.
- `-with-dag <filename.png>`: write a workflow graph.
