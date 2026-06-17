#!/bin/bash
set -e
echo "=== Est-ASR Pipeline setup ==="

# 1. Nextflow
echo "Installiin Nextflow..."
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
nextflow -version

# 2. Docker image
echo "Tõmban Docker image..."
docker pull eenokr/est-asr:latest

# 3. Võta konfid image'ist
echo "Kopeerin pipeline failid..."
sudo mkdir -p /opt/est-asr-pipeline
docker create --name tmp_setup eenokr/est-asr:latest
sudo docker cp tmp_setup:/opt/est-asr-pipeline/transcribe.nf /opt/est-asr-pipeline/
sudo docker cp tmp_setup:/opt/est-asr-pipeline/nextflow.config /opt/est-asr-pipeline/
docker rm tmp_setup

# 4. Transkribeerimise skript
echo "Loon transkribeeri käsu..."
sudo tee /usr/local/bin/transkribeeri << 'SCRIPT'
#!/bin/bash
set -e
if [ -z "$1" ]; then
  echo "Kasutus: transkribeeri <helifail.mp3>"
  exit 1
fi
FAIL="$1"
NIMI=$(basename "$FAIL" | sed 's/\.[^.]*$//')
TULEMUS="${2:-/opt/tulemused/$NIMI}"
mkdir -p "$TULEMUS"
echo "Transkribeerin: $FAIL"
cd /opt/est-asr-pipeline
nextflow run transcribe.nf -profile docker \
  --in "$FAIL" \
  --out_dir "$TULEMUS" \
  --nthreads 4 \
  --do_speaker_id false
echo "Valmis! Tulemus: $TULEMUS"
ls "$TULEMUS/"
SCRIPT
sudo chmod +x /usr/local/bin/transkribeeri

echo ""
echo "=== Setup valmis! ==="
echo "Kasutus: transkribeeri /tee/fail.mp3"
