#!/bin/bash
set -e
echo "=== Est-ASR Pipeline setup ==="

# Tuvasta OS
OS=$(uname -s)
ARCH=$(uname -m)
echo "Süsteem: $OS / $ARCH"

# 1. Java
if ! java -version 2>/dev/null; then
  echo "Installiin Java..."
  if [ "$OS" = "Darwin" ]; then
    brew install openjdk@17
    sudo ln -sfn $(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
  elif [ -f /etc/debian_version ]; then
    sudo apt-get install -y default-jre-headless
  else
    echo "Palun installi Java käsitsi: https://adoptium.net"
    exit 1
  fi
fi

# 2. Nextflow
echo "Installiin Nextflow..."
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
nextflow -version

# 3. Docker image
echo "Tõmban Docker image (~8GB, võtab aega)..."
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  echo "ARM tuvastatud - kasutan emulatsioonirežiimi"
  docker pull --platform linux/amd64 eenokr/est-asr:latest
else
  docker pull eenokr/est-asr:latest
fi

# 4. Pipeline failid
echo "Kopeerin pipeline failid..."
sudo mkdir -p /opt/est-asr-pipeline
docker create --name tmp_setup --platform linux/amd64 eenokr/est-asr:latest
sudo docker cp tmp_setup:/opt/est-asr-pipeline/transcribe.nf /opt/est-asr-pipeline/
sudo docker cp tmp_setup:/opt/est-asr-pipeline/nextflow.config /opt/est-asr-pipeline/
docker rm tmp_setup

# 5. Transkribeerimise skript
echo "Loon transkribeeri käsu..."
ARCH=$(uname -m)
PLATFORM_OPT=""
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  PLATFORM_OPT="--platform linux/amd64"
fi

sudo tee /usr/local/bin/transkribeeri << SCRIPT
#!/bin/bash
set -e
if [ -z "\$1" ]; then
  echo "Kasutus: transkribeeri <helifail.mp3>"
  exit 1
fi
FAIL="\$1"
NIMI=\$(basename "\$FAIL" | sed 's/\.[^.]*\$//')
TULEMUS="\${2:-/opt/tulemused/\$NIMI}"
mkdir -p "\$TULEMUS"
echo "Transkribeerin: \$FAIL"
cd /opt/est-asr-pipeline
NXF_DOCKER_LEGACY=true nextflow run transcribe.nf -profile docker $PLATFORM_OPT \
  --in "\$FAIL" \
  --out_dir "\$TULEMUS" \
  --nthreads 4 \
  --do_speaker_id false
echo "Valmis! Tulemus: \$TULEMUS"
ls "\$TULEMUS/"
SCRIPT
sudo chmod +x /usr/local/bin/transkribeeri

echo ""
echo "=== Setup valmis! ==="
echo "Kasutus: transkribeeri /tee/fail.mp3"
