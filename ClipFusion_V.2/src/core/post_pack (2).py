import random

class PostPackGenerator:
    def __init__(self, locale='pt'):
        self.locale = locale
        self.templates = {
            'Curiosidade': {
                'title': ["O segredo de {tema}", "{tema} – o que ninguém conta"],
                'description': ["Descubra {tema} que vai mudar sua visão sobre {nicho}."],
                'hashtags': ["#curiosidade", "#descubraagora", "#viral"]
            },
            'Medo': {
                'title': ["Cuidado com {tema}", "Isso pode destruir {algo}"],
                'description': ["Você sabia que {tema} pode estar arruinando seus resultados?"],
                'hashtags': ["#cuidado", "#alerta", "#fiqueatento"]
            },
        }

    def generate(self, cut_title, archetype, niche, tema=None):
        template = self.templates.get(archetype, self.templates['Curiosidade'])
        title = random.choice(template['title']).format(tema=tema or cut_title, nicho=niche, algo='seus resultados')
        description = random.choice(template['description']).format(tema=tema or cut_title, nicho=niche)
        hashtags = template['hashtags'] + [f"#{nicho.replace(' ', '')}", "#clipfusion"]
        pinned_comment = f"O que você achou? Comenta aqui embaixo! 👇"
        return {
            'title': title[:60],
            'description': description[:150],
            'hashtags': hashtags[:5],
            'pinned_comment': pinned_comment
        }
