from . import segment
import db

def generate_candidates(project_id, transcript_id, segments, min_dur=18, max_dur=35, pause_threshold=0.5):
    raw_candidates = segment.segment_by_pauses(segments, min_dur, max_dur, pause_threshold)
    candidate_ids = []
    for cand in raw_candidates:
        cid = db.save_candidate(project_id, transcript_id, cand['start'], cand['end'], cand['text'])
        candidate_ids.append(cid)
    return candidate_ids
