"""Synthetic in-memory integration checks; never reads real conversations."""
import asyncio
import json
from unittest.mock import AsyncMock, patch
from contextlib import asynccontextmanager
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.models.models import Base, User, Post, PostComment, Message, Chat, ChatMember, ChatType
from app.services import feed_comments as f


async def main():
    engine = create_async_engine('sqlite+aiosqlite:///:memory:')
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    checks = []
    with patch.object(f, 'notify_changed', new=AsyncMock()):
        async with factory() as db:
            await f.migrate_comments(db)
            await f.migrate_comments(db)
            users = [User(id=i, username=f'fixture{i}', display_name=f'Test {i}', email=f'{i}@example.invalid', hashed_password='unused', is_active=True) for i in (1,2,3)]
            db.add_all(users)
            db.add_all([Post(id=1, author_id=1, content='Fixture post', comments_count=0), Post(id=2, author_id=1, content='Other post', comments_count=0)])
            await db.flush()
            a = await f.create_comment({'post_id':1,'content':'First'}, db, users[0])
            b = await f.create_comment({'post_id':1,'content':'Reply','reply_to_id':a['id']}, db, users[1])
            c = await f.create_comment({'post_id':1,'content':'Nested reply','reply_to_id':b['id']}, db, users[2])
            assert c['reply_to_id']==b['id'] and b['reply_to_id']==a['id']
            assert all(k in b for k in ['sender_username','sender_display_name','sender_avatar_url','sender_badges','sent_at','edited_at','reactions'])
            checks.append('nested replies and normal-message author metadata')
            for bad in ({'post_id':2,'content':'Cross post','reply_to_id':a['id']}, {'post_id':1,'content':'x'*10001}, {'post_id':True,'content':'Invalid'}):
                try: await f.create_comment(bad, db, users[0])
                except ValueError: pass
                else: raise AssertionError('Invalid comment accepted')
            checks.append('cross-post reply and input limits rejected')
            for key in ['edit_post_comment','delete_post_comment']:
                try: await f.mutate_comment(key, {'post_id':1,'comment_id':a['id'],'content':'spoof'}, db, users[1])
                except ValueError: pass
                else: raise AssertionError('Forged author accepted')
            edited = await f.mutate_comment('edit_post_comment', {'post_id':1,'comment_id':a['id'],'content':'Edited'}, db, users[0])
            assert edited['edited_at'] and edited['content']=='Edited'
            for expected in (1,0):
                data = await f.mutate_comment('react_post_comment', {'post_id':1,'comment_id':a['id'],'reaction':'like'}, db, users[1])
                assert sum(data['reactions'].values())==expected
            deleted = await f.mutate_comment('delete_post_comment', {'post_id':1,'comment_id':b['id']}, db, users[1])
            assert deleted['is_deleted'] and not deleted['content']
            assert (await db.get(PostComment,c['id'])).reply_to_id==b['id']
            checks.append('author checks, editing, reaction toggle and retained children on deletion')
            first = await f.get_comments({'post_id':1,'page_size':2}, db, users[0])
            second = await f.get_comments({'post_id':1,'page_size':2,'after_id':first['comments'][-1]['id']}, db, users[0])
            assert first['has_more'] and not second['has_more'] and len(second['comments'])==1
            checks.append('bounded cursor pagination without missing or duplicated replies')
            source = await f.create_comment({'post_id':1,'content':'@niosai Проверь дату'}, db, users[0])
            assert len(db.info['feed_ai_jobs'])==1
            db.info.pop('feed_ai_jobs', None); db.info.pop('feed_changes', None)
            await db.commit()
        call = AsyncMock(return_value=('Я'*330, 40))
        bot = User(id=9, username='nios_ai', display_name='NiosAI', email='niosai@nios.mess',hashed_password='unused', is_active=True, is_bot=True)
        async with factory() as db:
            db.add(bot); await db.commit()
        with patch('app.database.AsyncSessionLocal',factory), patch('app.services.ai_svc.call_glm',call), patch('app.services.bot_svc.ensure_niosai',AsyncMock(return_value=bot)):
            await f.answer_feed_ai(1,1,source['id'],0)
            await f.answer_feed_ai(1,1,source['id'],0)
        assert call.await_count==1
        kwargs=call.call_args.kwargs
        assert kwargs['model_key']=='nios_lite_strong' and kwargs['allow_fallback'] is False and kwargs['strict_max_tokens'] and kwargs['use_tools']
        async with factory() as db:
            answer=await db.scalar(select(PostComment).where(PostComment.ai_source==f"1:{source['id']}"))
            assert answer and answer.author_id==9 and len(answer.content)==300 and answer.reply_to_id==source['id']
        checks.append('only Lite Strong, web tools enabled, 300-character hard cap, NiosAI author, idempotent answer')
        assert 'Не переписывай' in kwargs['system'] and 'прямой просьбе' in kwargs['system']
        async with factory() as db:
            from app.models.models import SupportTicket
            data = {'post_id':1,'comment_id':answer.id}
            report = await f.report_ai_quality(data, db, users[0])
            repeated = await f.report_ai_quality(data, db, users[0])
            assert repeated['already_reported'] and repeated['ticket_id']==report['ticket_id']
            ticket = await db.get(SupportTicket, report['ticket_id'])
            assert ticket.ticket_type=='ai_quality' and answer.content in ticket.body and 'Fixture post' in ticket.body
            assert (await f.payloads([answer],db,1))[0]['system_event']['is_niosai_reply']
            for invalid in ({'post_id':1,'comment_id':a['id']}, {'post_id':2,'comment_id':answer.id}):
                try: await f.report_ai_quality(invalid,db,users[0])
                except ValueError: pass
                else: raise AssertionError('Non-AI or cross-post quality report accepted')
            await db.commit()
        checks.append('quality complaints capture selected evidence once in support queue, reject human/cross-post targets; no abuse sanctions')

        async with factory() as db:
            identity_source = await f.create_comment({'post_id':1,'content':'@ai КТО ТЫ?'},db,users[0])
            db.info.pop('feed_ai_jobs',None);db.info.pop('feed_changes',None)
            await db.commit()
        identity_call = AsyncMock(return_value=('Я NiosAI. Чем помочь?', 10))
        with patch('app.database.AsyncSessionLocal',factory), patch('app.services.ai_svc.call_glm',identity_call), patch('app.services.bot_svc.ensure_niosai',AsyncMock(return_value=bot)):
            await f.answer_feed_ai(1,1,identity_source['id'],0)
        async with factory() as db:
            identity_reply = await db.scalar(select(PostComment).where(PostComment.ai_source==f"1:{identity_source['id']}"))
            assert identity_reply and identity_reply.content=='Я NiosAI. Чем помочь?' and identity_reply.author_id==9
        assert identity_call.await_count==1 and 'NiosAI' in identity_call.call_args.kwargs['system']
        checks.append('identity is defined in the model prompt; identity questions still call the model')
        async with factory() as db:
            follow = await f.create_comment({'post_id':1,'content':'А подробнее?','reply_to_id':answer.id}, db, users[0])
            assert len(db.info.get('feed_ai_jobs',[]))==1
            db.info.pop('feed_ai_jobs',None);db.info.pop('feed_changes',None)
            human_reply = await f.create_comment({'post_id':1,'content':'Обычный ответ','reply_to_id':a['id']}, db, users[1])
            assert not db.info.get('feed_ai_jobs')
            db.info.pop('feed_changes',None)
            await db.commit()
        follow_call=AsyncMock(return_value=('Продолжение ответа.',20))
        with patch('app.database.AsyncSessionLocal',factory), patch('app.services.ai_svc.call_glm',follow_call), patch('app.services.bot_svc.ensure_niosai',AsyncMock(return_value=bot)):
            await f.answer_feed_ai(1,1,follow['id'],0)
        assert follow_call.await_count==1
        history=follow_call.call_args.kwargs['history']
        assert history[-1]==('assistant',answer.content) and history[0][0]=='user'
        async with factory() as db:
            saved=await db.scalar(select(PostComment).where(PostComment.ai_source==f"1:{follow['id']}"))
            assert saved and saved.reply_to_id==follow['id'] and saved.author_id==9
        checks.append('reply to NiosAI triggers once without mention and includes thread context; human reply does not trigger')
        async with factory() as db:
            channel=Chat(id=20,chat_type=ChatType.CHANNEL,name='Fixture channel',created_by=1,comments_enabled=True,comments_chat_id=21)
            group=Chat(id=21,chat_type=ChatType.GROUP,name='Fixture replies',created_by=1)
            db.add_all([channel,group]); await db.flush()
            db.add(ChatMember(chat_id=20,user_id=1))
            post=Message(id=100,chat_id=20,sender_id=1)
            db.add(post); await db.flush()
            a=await f.create_channel_comment({'channel_id':20,'post_id':100,'content':'Channel first'},db,users[0])
            b=await f.create_channel_comment({'channel_id':20,'post_id':100,'content':'Channel nested','reply_to_id':a['id']},db,users[0])
            assert b['reply_to_id']==a['id']
            result=await f.get_channel_comments({'channel_id':20,'post_id':100},db,users[0])
            assert len(result['comments'])==2
            enc=f.encrypt_text('Ответ бота в канале')
            bot_comment=Message(chat_id=21,sender_id=9,comment_post_id=100,encrypted_content=enc['ciphertext'],content_iv=enc['iv'],content_tag=enc['tag'])
            db.add(bot_comment);await db.flush()
            await f.create_channel_comment({'channel_id':20,'post_id':100,'content':'Продолжи','reply_to_id':bot_comment.id},db,users[0])
            assert len(db.info.get('feed_ai_jobs',[]))==1
            db.info.pop('feed_ai_jobs',None)
            try: await f.get_channel_comments({'channel_id':20,'post_id':100},db,users[1])
            except ValueError: pass
            else: raise AssertionError('Private channel leaked')
            checks.append('channel thread root retained and nonmembers rejected')
            db.info.pop('feed_changes',None)
            await db.rollback()
        assert f.MENTION.search('@ai привет') and f.MENTION.search('@NiosAI, привет')
        assert not f.MENTION.search('name@ai.example') and not f.MENTION.search('@aibot')
        checks.append('both mentions with complete token boundaries')
        # Exercise the real generator: tool invocation must not switch provider,
        # inherit a Plus output cap, or retry a refusal on the stronger model.
        from app.services import ai_svc
        from app.services.ai_credits import CreditReservation
        @asynccontextmanager
        async def credit(_user): yield CreditReservation()
        @asynccontextmanager
        async def slot(*args, **kwargs): yield
        provider = AsyncMock(side_effect=[
            {'choices':[{'message':{'content':None,'tool_calls':[{'id':'lookup','function':{'name':'web_search','arguments':'{"query":"fixture"}'}}]}}]},
            {'choices':[{'message':{'content':'Короткий ответ.'}}]},
        ])
        tool = AsyncMock(return_value='Synthetic search result')
        users[0].ai_model='nios_prime'
        with patch.object(ai_svc,'credit_request',credit), patch.object(ai_svc,'model_slot',slot), patch.object(ai_svc,'_post_chat',provider), patch.object(ai_svc,'run_tool',tool):
            result,_ = await ai_svc.call_glm('fixture',user=users[0],model_key='nios_lite_strong',allow_fallback=False,
                max_tokens=512,strict_max_tokens=True,use_tools=True)
        assert result=='Короткий ответ.' and tool.call_args.args[0]=='web_search'
        assert all(c.args[1]['model']==ai_svc.settings.POLZA_STRONG_MODEL and c.args[1]['max_tokens']<=512 for c in provider.call_args_list)
        assert users[0].ai_model=='nios_prime'
        checks.append('actual tool round keeps fixed Lite Strong provider and output cap without changing saved model')
        launch = AsyncMock()
        with patch.object(f,'answer_feed_ai',launch):
            async with factory() as db:
                f.queue_feed_ai(db,1,1,source['id'],'@ai fixture',0)
                await db.rollback()
                # An explicit rollback on a transaction with work discards queued jobs.
                assert not db.info.get('feed_ai_jobs') or not db.in_transaction()
                db.info.pop('feed_ai_jobs',None)
                await db.execute(text('SELECT 1'))
                f.queue_feed_ai(db,1,1,source['id'],'@ai fixture',0)
                await db.rollback()
                await asyncio.sleep(0)
                assert launch.await_count==0
                await db.execute(text('SELECT 1'))
                f.queue_feed_ai(db,1,1,source['id'],'@ai fixture',0)
                await db.commit()
                await asyncio.sleep(0)
                assert launch.await_count==1
        checks.append('AI launches after commit; rollback never calls provider')
    legacy = create_async_engine('sqlite+aiosqlite:///:memory:')
    async with legacy.begin() as db:
        for statement in [
            'CREATE TABLE post_comments (id INTEGER PRIMARY KEY,post_id INTEGER,author_id INTEGER,content TEXT,created_at TIMESTAMP)',
            'CREATE TABLE messages (id INTEGER PRIMARY KEY,chat_id INTEGER,reply_to_id INTEGER)',
            'CREATE TABLE chats (id INTEGER PRIMARY KEY,comments_chat_id INTEGER)',
            "INSERT INTO post_comments VALUES(1,1,1,'Existing comment',NULL)",
            'INSERT INTO chats VALUES(20,21)',
            'INSERT INTO messages VALUES(100,20,NULL)',
            'INSERT INTO messages VALUES(101,21,100)',
        ]: await db.execute(text(statement))
        await f.migrate_comments(db)
        await f.migrate_comments(db)
        assert (await db.execute(text('SELECT content,reply_to_id,is_deleted FROM post_comments'))).one()==('Existing comment',None,0)
        assert (await db.execute(text('SELECT comment_post_id FROM messages WHERE id=101'))).scalar()==100
    await legacy.dispose()
    checks.append('legacy additive migration preserves comments and backfills channel roots; repeatable')
    for task in list(f._tasks):
        task.cancel()
    if f._tasks: await asyncio.gather(*f._tasks,return_exceptions=True)
    await engine.dispose()
    print(json.dumps({'passed':len(checks),'checks':checks},ensure_ascii=False))

asyncio.run(main())
