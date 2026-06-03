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

### CPU and memory configuration

The CPU/Kaldi workflow uses two shared parameters for the heavier steps:

- `--nthreads <N>`: number of CPU threads requested by speaker ID and decoding.
- `--process_memory <SIZE>`: memory requested by diarization, speaker ID, decoding, and RNNLM rescoring.

For example, to request four CPU threads and 8 GB for the main processing steps:

    nextflow run transcribe.nf --in /path/to/audio.mp3 --nthreads 4 --process_memory 8GB

Some lightweight steps have fixed resource settings in `transcribe.nf`, for example `to_wav` uses `500MB` and 2 CPUs, `language_id` uses `4GB`, `mfcc` uses `1GB`, `lattice2ctm` uses `4GB` and 2 CPUs, and `punctuation` uses `4GB`. The `--process_memory` parameter does not override those fixed per-process settings.

The bundled `lowmem` profile is useful on small machines:

    nextflow run transcribe.nf -profile lowmem --in /path/to/audio.mp3

It sets the workflow to run one task at a time, uses one thread for threaded Kaldi steps, lowers `process_memory` to `3GB`, and enables Docker with a hard container limit:

    process.maxForks = 1
    executor.queueSize = 1
    params.nthreads = 1
    params.process_memory = "3GB"
    docker.runOptions = "--memory=5g --memory-swap=5g --cpus=1"

Nextflow `cpus` and `memory` directives are resource requests used for scheduling. With the local executor, they are not always hard operating-system limits. When running through Docker, `docker.runOptions` is the part that enforces actual container-level CPU and memory caps.

For custom limits, create a small config file, for example `resources.config`:

    params {
        nthreads = 4
        process_memory = '8GB'
    }

    process {
        maxForks = 1

        withName: 'one_pass_decoding' {
            cpus = 4
            memory = '8GB'
        }

        withName: 'speaker_id' {
            cpus = 4
            memory = '8GB'
        }

        withName: 'punctuation' {
            memory = '6GB'
        }
    }

    docker.runOptions = '--memory=10g --memory-swap=10g --cpus=4'

Run it with:

    nextflow run transcribe.nf -c resources.config --in /path/to/audio.mp3

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
