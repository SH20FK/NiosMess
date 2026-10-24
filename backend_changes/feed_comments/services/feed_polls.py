"""Anonymous NiosGram ballots. Only aggregate counts and the caller's vote leave the server."""
import json
from sqlalchemy import select, text
from app.models.models import Post


async def migrate(db):
    columns = {row[1] for row in (await db.execute(text('PRAGMA table_info(posts)'))).all()}
    if 'interactive_json' not in columns:
        await db.execute(text('ALTER TABLE posts ADD COLUMN interactive_json TEXT'))
    await db.execute(text('''CREATE TABLE IF NOT EXISTS feed_poll_votes (
        post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        choices_json TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY(post_id,user_id))'''))


def validate(value):
    if value is None:
        return None
    if not isinstance(value, dict) or value.get('kind') not in ('poll', 'quiz'):
        raise ValueError('Invalid anonymous ballot')
    title, items = value.get('title'), value.get('items')
    if not isinstance(title, str) or not 1 <= len(title.strip()) <= 180:
        raise ValueError('Question must contain 1–180 characters')
    if not isinstance(items, list) or not 2 <= len(items) <= 10 or any(
            not isinstance(item, str) or not 1 <= len(item.strip()) <= 100 for item in items):
        raise ValueError('A poll needs 2–10 nonempty options')
    items = [item.strip() for item in items]
    if len(set(items)) != len(items):
        raise ValueError('Duplicate poll options')
    result = dict(kind=value['kind'], title=title.strip(), items=items,
                  multiple=bool(value.get('multiple')) if value['kind'] == 'poll' else False)
    if value['kind'] == 'quiz':
        correct, explanation = value.get('correct'), value.get('explanation', '')
        if type(correct) is not int or not 0 <= correct < len(items):
            raise ValueError('Invalid correct answer')
        if not isinstance(explanation, str) or len(explanation) > 500:
            raise ValueError('Invalid quiz explanation')
        result.update(correct=correct, explanation=explanation)
    return result


async def payload(db, post, viewer_id):
    if not post.interactive_json:
        return None
    definition = json.loads(post.interactive_json)
    counts = [0] * len(definition['items'])
    # Aggregate in SQL: individual voters are never loaded into a public response.
    for choice, count in (await db.execute(text('''SELECT CAST(j.value AS INTEGER),COUNT(*)
            FROM feed_poll_votes v,json_each(v.choices_json) j
            WHERE v.post_id=:post_id GROUP BY CAST(j.value AS INTEGER)'''), {'post_id': post.id})).all():
        if 0 <= choice < len(counts): counts[choice] = count
    total = await db.scalar(text('SELECT COUNT(*) FROM feed_poll_votes WHERE post_id=:id'), {'id': post.id})
    mine = await db.scalar(text('SELECT choices_json FROM feed_poll_votes WHERE post_id=:post AND user_id=:user'),
                           {'post': post.id, 'user': viewer_id})
    result = {k: definition[k] for k in ('kind', 'title', 'items', 'multiple')}
    result.update(anonymous=True, counts=counts, total_voters=total, my_choices=json.loads(mine) if mine else [])
    if mine and definition['kind'] == 'quiz':
        result.update(correct=definition['correct'], explanation=definition.get('explanation', ''))
    return result


async def vote(data, db, user):
    from app.services.feed_comments import integer, changed
    post = await db.get(Post, integer(data.get('post_id'), 'post_id'))
    if not post or not post.interactive_json:
        raise ValueError('Poll not found')
    definition = json.loads(post.interactive_json)
    choices = data.get('choices')
    if not isinstance(choices, list) or not 1 <= len(choices) <= 10 or any(
            type(c) is not int or not 0 <= c < len(definition['items']) for c in choices) or len(set(choices)) != len(choices):
        raise ValueError('Invalid choices')
    if not definition['multiple'] and len(choices) != 1:
        raise ValueError('Choose one option')
    params = dict(post=post.id, user=user.id, choices=json.dumps(sorted(choices)))
    if definition['kind'] == 'quiz':
        await db.execute(text('INSERT OR IGNORE INTO feed_poll_votes(post_id,user_id,choices_json) VALUES(:post,:user,:choices)'), params)
    else:
        await db.execute(text('''INSERT INTO feed_poll_votes(post_id,user_id,choices_json) VALUES(:post,:user,:choices)
            ON CONFLICT(post_id,user_id) DO UPDATE SET choices_json=excluded.choices_json'''), params)
    changed(db, 0, post.id)
    return {'poll': await payload(db, post, user.id)}
