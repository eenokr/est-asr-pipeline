#! /usr/bin/env python3
import json
import sys
import argparse

def get_word(word):
    return word.get("word_with_punctuation", word["word"])

def get_speaker_label(json_data, speaker_id):
    speaker = json_data.get("speakers", {}).get(speaker_id, {})
    return speaker.get("name", speaker_id).removeprefix("audio-")

def extract_text_from_json(json_data):
    """Extract plain text from JSON transcription format"""
    text_parts = []
    
    sections = json_data.get("sections", [])
    for section in sections:
        if section["type"] == "speech":
            turns = section.get("turns", [])
            for turn in turns:
                words = turn.get("words", [])
                if words:
                    # Join words with spaces
                    turn_text = " ".join([get_word(word) for word in words])
                    text_parts.append(turn_text)
                elif turn.get("transcript"):
                    text_parts.append(turn["transcript"])
    
    # Join all turns with line breaks
    return "\n".join(text_parts)

def extract_speaker_text_from_json(json_data):
    text_parts = []

    for section in json_data.get("sections", []):
        for turn in section.get("turns", []):
            if turn.get("transcript"):
                speaker = get_speaker_label(json_data, turn["speaker"])
                text_parts.append(f"{speaker}: {turn['transcript']}")

    return "\n".join(text_parts)

def main():
    parser = argparse.ArgumentParser("Converts JSON format to plain text")
    parser.add_argument("--speaker-labels", action="store_true", help="prefix each turn with the speaker name or ID")
    parser.add_argument('json', nargs="?", default="-", help="JSON input file, or stdin when omitted")
    
    args = parser.parse_args()
    
    try:
        if args.json == "-":
            trans = json.load(sys.stdin)
        else:
            with open(args.json, encoding="utf-8") as f:
                trans = json.load(f)

        text = extract_speaker_text_from_json(trans) if args.speaker_labels else extract_text_from_json(trans)
        print(text)
    except Exception as e:
        print(f"Error processing JSON file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
