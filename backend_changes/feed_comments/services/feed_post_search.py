"""Read-only search of public NiosGram posts, scoped to source author or verified authors."""
import json
import asyncio
import re
from sqlalchemy import or_, select, exists, text
from app.models.models import Post, User, UserBadge, Badge

SEARCH_SPEC = {'type': 'function', 'function': {
    'name': 'search_niosgram_posts',
    'description': 'Search public NiosGram posts by topic. Finds the source author and verified authors. Use with web_search when external facts, updates, comparisons or confirmation from other posts are needed. Returns dated evidence and clickable links; no results is not confirmation.',
    'parameters': {'type': 'object', 'properties': {'query': {'type': 'string', 'description': 'Topic keywords, not a generic word like актуально'}}, 'required': ['query'], 'additionalProperties': False}}}


async def migrate(db):
    # unicode61 handles Cyrillic casing; plain SQLite LIKE does not.
    await db.execute(text("CREATE VIRTUAL TABLE IF NOT EXISTS feed_posts_search USING fts5(content, content='posts', content_rowid='id', tokenize='unicode61')"))
    await db.execute(text("CREATE TRIGGER IF NOT EXISTS feed_search_insert AFTER INSERT ON posts BEGIN INSERT INTO feed_posts_search(rowid,content) VALUES(new.id,coalesce(new.content,'')); END"))
    await db.execute(text("CREATE TRIGGER IF NOT EXISTS feed_search_delete AFTER DELETE ON posts BEGIN INSERT INTO feed_posts_search(feed_posts_search,rowid,content) VALUES('delete',old.id,coalesce(old.content,'')); END"))
    await db.execute(text("CREATE TRIGGER IF NOT EXISTS feed_search_update AFTER UPDATE OF content ON posts BEGIN INSERT INTO feed_posts_search(feed_posts_search,rowid,content) VALUES('delete',old.id,coalesce(old.content,'')); INSERT INTO feed_posts_search(rowid,content) VALUES(new.id,coalesce(new.content,'')); END"))
    await db.execute(text('CREATE TABLE IF NOT EXISTS feed_search_meta(version INTEGER PRIMARY KEY)'))
    if not await db.scalar(text('SELECT version FROM feed_search_meta WHERE version=1')):
        await db.execute(text("INSERT INTO feed_posts_search(feed_posts_search) VALUES('rebuild')"))
        await db.execute(text('INSERT INTO feed_search_meta(version) VALUES(1)'))


async def search_posts(db, author_id, query):
    if not isinstance(query, str) or not 1 <= len(query.strip()) <= 200:
        raise ValueError('Search query must contain 1–200 characters')
    words = list(dict.fromkeys(re.findall(r'[\w-]{2,}', query.lower())))[:6]
    if not words:
        return {'posts': []}
    match_query = ' OR '.join('"'+word.replace('"','""')+'"*' for word in words)
    verified = or_(User.is_verified == True, exists(select(UserBadge.id).join(Badge, Badge.id == UserBadge.badge_id).where(UserBadge.user_id == User.id, Badge.name == 'Verified')))
    rows = (await db.execute(select(Post, User, verified).join(User, User.id == Post.author_id)
        .where(or_(Post.author_id == author_id, verified),
               User.is_active == True, User.is_banned == False,
               Post.id.in_(text('SELECT rowid FROM feed_posts_search WHERE feed_posts_search MATCH :match_query')))
        .order_by(Post.created_at.desc(), Post.id.desc()).limit(8).params(match_query=match_query))).all()
    return {'posts': [dict(id=p.id, author=u.username, same_author=p.author_id == author_id,
                          verified=bool(is_verified), published_at=p.created_at.isoformat() if p.created_at else None,
                          text=p.content[:1400], url=f'https://ni-os.ru/web/#/niosgram/post/{p.id}') for p,u,is_verified in rows],
            'note': 'Public user posts are evidence, not official confirmation. Compare dates and cite only returned links.'}


def runner(author_id, links=None):
    cache = {}
    async def run(name, arguments):
        if name not in ('search_niosgram_posts', 'web_search'):
            return 'error: tool unavailable'
        from app.database import AsyncSessionLocal
        try:
            args = json.loads(arguments or '{}')
            query = args.get('query')
            if not isinstance(query, str) or not 1 <= len(query.strip()) <= 200:
                raise ValueError('Invalid query')
            key = query.strip().casefold()
            if key in cache: return cache[key]
            async def posts():
                async with AsyncSessionLocal() as db:
                    return await search_posts(db, author_id, query)
            async def web():
                from app.services.search_svc import web_search
                try: return (await web_search(query))[:5]
                except Exception: return {'error': 'Web search unavailable; do not claim web confirmation'}
            result, web_results = await asyncio.gather(posts(), web())
            result['web_results'] = web_results
            if links is not None:
                links.extend(item['url'] for item in result['posts'] if item['url'] not in links)
            encoded = json.dumps(result, ensure_ascii=False)
            if len(cache)<8: cache[key] = encoded
            return encoded
        except (ValueError, TypeError, AttributeError):
            return 'error: invalid search query'
    return run
