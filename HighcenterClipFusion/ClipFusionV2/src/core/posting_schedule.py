import random
from datetime import datetime, timedelta

class PostingSchedule:
    def __init__(self, platform='tiktok', base_hours=None):
        self.platform = platform
        self.base_hours = base_hours or [9, 12, 18, 21]

    def generate(self, count=10, start_date=None, jitter_minutes=15):
        if start_date is None:
            start_date = datetime.now()
        schedule = []
        current = start_date
        for i in range(count):
            hour = random.choice(self.base_hours)
            candidate = current.replace(hour=hour, minute=0, second=0, microsecond=0)
            jitter = timedelta(minutes=random.randint(-jitter_minutes, jitter_minutes),
                               seconds=random.randint(0, 59))
            post_time = candidate + jitter
            current += timedelta(days=1)
            schedule.append(post_time)
        return schedule

    def format_schedule(self, schedule):
        lines = [f"📅 Agenda de postagens ({self.platform})"]
        for i, dt in enumerate(schedule, 1):
            lines.append(f"  #{i:02d} - {dt.strftime('%d/%m/%Y %H:%M:%S')}")
        return "\n".join(lines)
