class DecisionEngine:
    def __init__(self, thresholds=None):
        self.thresholds = thresholds or {'approved': 9.0, 'rework': 7.0, 'discard': 0.0}

    def decide(self, local_score, ai_score=None, ai_confidence=None):
        if ai_score is None:
            if local_score >= self.thresholds['approved']:
                return 'approved', f"Score local alto ({local_score:.1f})"
            elif local_score >= self.thresholds['rework']:
                return 'rework', f"Score local médio ({local_score:.1f})"
            else:
                return 'discard', f"Score local baixo ({local_score:.1f})"
        combined = (local_score + ai_score) / 2
        if combined >= self.thresholds['approved']:
            return 'approved', f"Consenso: local {local_score:.1f}, IA {ai_score:.1f}"
        elif combined >= self.thresholds['rework']:
            return 'rework', f"Divergência: local {local_score:.1f}, IA {ai_score:.1f}"
        else:
            return 'discard', f"Baixo consenso: local {local_score:.1f}, IA {ai_score:.1f}"

    def batch_decide(self, candidates_with_scores):
        decisions = []
        for cand in candidates_with_scores:
            decision, reason = self.decide(cand.get('local_score', 0), cand.get('ai_score'))
            decisions.append({
                'candidate_id': cand.get('id'),
                'decision': decision,
                'reason': reason,
                'combined_score': (cand.get('local_score', 0) + cand.get('ai_score', 0)) / 2
            })
        return decisions
