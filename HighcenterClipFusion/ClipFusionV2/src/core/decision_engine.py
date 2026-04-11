class DecisionEngine:
    def __init__(self, thresholds=None):
        self.thresholds = thresholds or {'approved': 9.0, 'rework': 7.0, 'discard': 0.0}

    def decide(self, local_score, ai_score=None, platform_fit=0.0, trans_quality=0.0):
        if ai_score is None:
            final_score = round(float(local_score), 2)
            if final_score >= self.thresholds['approved']:
                return 'approved', f"Score local alto ({final_score:.2f})"
            elif final_score >= self.thresholds['rework']:
                return 'retry', f"Score local médio ({final_score:.2f})"
            else:
                return 'rejected', f"Score local baixo ({final_score:.2f})"
        final_score = (
            float(local_score) * 0.5 +
            float(ai_score) * 0.3 +
            float(platform_fit) * 0.1 +
            float(trans_quality) * 0.1
        )
        final_score = round(final_score, 2)
        if final_score >= self.thresholds['approved']:
            return 'approved', f"Final {final_score:.2f}"
        elif final_score >= self.thresholds['rework']:
            return 'retry', f"Final {final_score:.2f}"
        else:
            return 'rejected', f"Final {final_score:.2f}"

    def batch_decide(self, candidates_with_scores):
        decisions = []
        for cand in candidates_with_scores:
            decision, reason = self.decide(
                cand.get('local_score', 0),
                cand.get('ai_score'),
                cand.get('platform_fit', 0.0),
                cand.get('trans_quality', 0.0)
            )
            decisions.append({
                'candidate_id': cand.get('id'),
                'decision': decision,
                'reason': reason,
                'combined_score': (cand.get('local_score', 0) + cand.get('ai_score', 0)) / 2 if cand.get('ai_score') else cand.get('local_score', 0)
            })
        return decisions
