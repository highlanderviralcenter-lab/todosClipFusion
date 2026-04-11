import db

class LearningEngine:
    def __init__(self):
        pass

    def update_weights_from_performance(self, project_id=None):
        with db.get_db() as conn:
            query = """
                SELECT c.*, p.views, p.likes, p.shares, p.comments
                FROM cuts c
                JOIN performances p ON c.id = p.cut_id
            """
            if project_id:
                query += " WHERE c.project_id = ?"
                rows = conn.execute(query, (project_id,)).fetchall()
            else:
                rows = conn.execute(query).fetchall()
        if not rows:
            return
        print("LearningEngine: análise de performance ainda não implementada.")
