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
        prompt, context_history=f.feed_request('Original post','а где же «круто»',[('assistant','Previous answer')])
        assert prompt=='а где же «круто»' and context_history[0][1].endswith('Original post')
        regeneration=AsyncMock(return_value=('@ai Круто! @niosai — полезное обновление.',10))
        async with factory() as db:
            before_count=await db.scalar(select(Post.comments_count).where(Post.id==1))
        with patch('app.database.AsyncSessionLocal',factory), patch('app.services.ai_svc.call_glm',regeneration):
            await f.answer_feed_ai(1,1,source['id'],0,replace_id=answer.id)
        async with factory() as db:
            replaced=await db.get(PostComment,answer.id)
            assert replaced and replaced.edited_at and '@ai' not in replaced.content.lower() and '@niosai' not in replaced.content.lower()
            assert replaced.content.startswith('Круто!') and replaced.reply_to_id==source['id']
            assert await db.scalar(select(Post.comments_count).where(Post.id==1))==before_count
            assert (await db.get(PostComment,follow['id'])).reply_to_id==answer.id
        checks.append('post context stays separate from latest reply; regeneration preserves message IDs, counts and child replies; forbidden self-mentions removed')

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
        provider = AsyncMock(side_effect=[
            {'choices':[{'message':{'content':None,'tool_calls':[{'id':'lookup','function':{'name':'web_search','arguments':'{"query":"fixture"}'}}]}}]},
            {'choices':[{'message':{'content':'Evidence checked.'}}]},
        ])
        scoped_search=AsyncMock(return_value='Combined web and post evidence')
        default_tool=AsyncMock()
        with patch.object(ai_svc,'credit_request',credit),patch.object(ai_svc,'model_slot',slot),patch.object(ai_svc,'_post_chat',provider),patch.object(ai_svc,'run_tool',default_tool):
            await ai_svc.call_glm('fixture',user=None,model_key='nios_lite_strong',allow_fallback=False,
                system=f.FEED_SYSTEM,replace_system=True,max_tokens=512,strict_max_tokens=True,use_tools=True,
                tool_names=('web_search',),local_tool_runner=scoped_search,local_tool_names=('web_search',))
        assert scoped_search.await_count==1 and default_tool.await_count==0
        assert provider.call_args_list[0].args[1]['messages'][0]['content']==f.FEED_SYSTEM
        checks.append('real generation dispatches feed web search through combined evidence runner and uses one nonconflicting system prompt')
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
    from app.services import feed_polls, custom_emojis, feed_post_search
    from app.models.models import CustomEmojiSet, CustomEmoji
    async with factory() as db:
        await feed_polls.migrate(db)
        await feed_polls.migrate(db)
        quiz = Post(id=50,author_id=1,content='Quiz',interactive_json=json.dumps(feed_polls.validate(
            {'kind':'quiz','title':'Question?','items':['A','B'],'correct':1,'explanation':'Because B'})))
        poll = Post(id=51,author_id=1,content='Poll',interactive_json=json.dumps(feed_polls.validate(
            {'kind':'poll','title':'Choose','items':['A','B','C'],'multiple':True})))
        db.add_all([quiz,poll]);await db.flush()
        hidden=await feed_polls.payload(db,quiz,1)
        assert hidden['anonymous'] and 'correct' not in hidden and 'explanation' not in hidden
        chosen=await feed_polls.vote({'post_id':50,'choices':[0]},db,users[1])
        assert chosen['poll']['correct']==1 and chosen['poll']['my_choices']==[0]
        again=await feed_polls.vote({'post_id':50,'choices':[1]},db,users[1])
        assert again['poll']['my_choices']==[0] and again['poll']['total_voters']==1
        author_view=await feed_polls.payload(db,quiz,1)
        assert 'correct' not in author_view and author_view['my_choices']==[]
        assert set(author_view)=={'kind','title','items','multiple','anonymous','counts','total_voters','my_choices'}
        checks.append('anonymous quiz exposes no voters/correct answer before voting; first vote cannot be changed')
        await feed_polls.vote({'post_id':51,'choices':[0,1]},db,users[1])
        changed_vote=await feed_polls.vote({'post_id':51,'choices':[2]},db,users[1])
        assert changed_vote['poll']['counts']==[0,0,1] and changed_vote['poll']['total_voters']==1
        for invalid in ([],[True],[4],[0,0]):
            try: await feed_polls.vote({'post_id':51,'choices':invalid},db,users[1])
            except ValueError: pass
            else: raise AssertionError('Invalid ballot accepted')
        checks.append('anonymous multiple-choice polls atomically replace own selection without duplicating totals; malformed votes rejected')
        db.add_all([CustomEmojiSet(id=30,owner_id=2,name='public_pack',title='Public',is_public=True),
                    CustomEmojiSet(id=31,owner_id=3,name='private_pack',title='Private',is_public=False)])
        await db.flush()
        db.add_all([CustomEmoji(id=30,set_id=30,shortcode='public_test',file_path='emoji/a.png',media_type='image/png',is_adaptive=True,width=128,height=128,file_size=123),
                    CustomEmoji(id=31,set_id=31,shortcode='private_test',file_path='emoji/b.png',media_type='image/png',width=128,height=128,file_size=123)])
        await db.flush()
        resolved=await custom_emojis.resolve_emojis({'shortcodes':['public_test','private_test']},db,users[0])
        assert len(resolved['emojis'])==1 and resolved['emojis'][0]['is_adaptive']
        for data in ({'shortcodes':['x']*101},{'shortcodes':['../secret']}):
            try: await custom_emojis.resolve_emojis(data,db,users[0])
            except ValueError: pass
            else: raise AssertionError('Unbounded emoji lookup accepted')
        checks.append('public custom emoji resolve for nonsubscribers; private pack metadata remains hidden; bounded validated batch')
        verified=await db.get(User,2);verified.is_verified=True
        db.add_all([Post(id=60,author_id=1,content='Bluetooth author update'),
                    Post(id=61,author_id=2,content='Bluetooth verified update'),
                    Post(id=62,author_id=3,content='Bluetooth unrelated author')])
        await db.flush()
        await feed_post_search.migrate(db);await feed_post_search.migrate(db)
        search=await feed_post_search.search_posts(db,1,'Bluetooth')
        assert {p['id'] for p in search['posts']}=={60,61}
        assert all(p['url'].endswith('/'+str(p['id'])) and p['published_at'] for p in search['posts'])
        checks.append('NiosGram search returns dated source-author/verified public posts and real links, excludes unrelated authors')
        russian=Post(id=63,author_id=1,content='ОБНОВЛЕНИЕ мессенджера')
        db.add(russian);await db.flush()
        assert (await feed_post_search.search_posts(db,1,'обновление'))['posts'][0]['id']==63
        russian.content='ДРУГАЯ публикация';await db.flush()
        assert not (await feed_post_search.search_posts(db,1,'обновление'))['posts']
        await db.delete(russian);await db.flush()
        assert not (await feed_post_search.search_posts(db,1,'другая'))['posts']
        checks.append('indexed Cyrillic search is case-insensitive and follows post creation, edits and deletion without rebuilding on every request')

        links=[]
        web=AsyncMock(return_value=[{'title':'External evidence','snippet':'Fixture','link':'https://example.invalid/source'}])
        with patch('app.database.AsyncSessionLocal',factory),patch('app.services.search_svc.web_search',web):
            run=feed_post_search.runner(1,links)
            combined=json.loads(await run('web_search','{"query":"Bluetooth"}'))
            repeated=await run('search_niosgram_posts','{"query":"Bluetooth"}')
        assert combined['posts'] and combined['web_results'] and web.await_count==1
        assert links and json.loads(repeated)==combined
        answer=f.public_answer('@ai '+('Text '*100),links)
        assert len(answer)<=300 and answer.endswith(links[0]) and '@ai' not in answer
        assert '/post/999' not in f.public_answer('Invented https://ni-os.ru/web/#/niosgram/post/999')
        checks.append('evidence search always checks web and NiosGram, caches duplicate query, preserves complete validated post link within 300 characters')
        valid=b'<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0L1 1"/></svg>'
        assert custom_emojis.validate_image(valid,'svg')[:2]==(128,128)
        for invalid in (b'<svg><script>alert(1)</script></svg>',b'<svg><image href="https://example.invalid/x"/></svg>',b'not png'):
            try: custom_emojis.validate_image(invalid,'svg' if invalid.startswith(b'<') else 'png')
            except ValueError: pass
            else: raise AssertionError('Invalid/active emoji image accepted')
        checks.append('custom emoji upload inspects actual bytes and rejects active SVG/external resources and invalid raster content')

        db.info.pop('feed_changes',None);await db.commit()
    legacy = create_async_engine('sqlite+aiosqlite:///:memory:')
    async with legacy.begin() as db:
        for statement in [
            'CREATE TABLE post_comments (id INTEGER PRIMARY KEY,post_id INTEGER,author_id INTEGER,content TEXT,created_at TIMESTAMP)',
            'CREATE TABLE messages (id INTEGER PRIMARY KEY,chat_id INTEGER,reply_to_id INTEGER)',
            'CREATE TABLE chats (id INTEGER PRIMARY KEY,comments_chat_id INTEGER)',
            'CREATE TABLE posts (id INTEGER PRIMARY KEY, content TEXT)',
            "INSERT INTO posts VALUES(1,'Existing post')",
            "INSERT INTO post_comments VALUES(1,1,1,'Existing comment',NULL)",
            'INSERT INTO chats VALUES(20,21)',
            'INSERT INTO messages VALUES(100,20,NULL)',
            'INSERT INTO messages VALUES(101,21,100)',
        ]: await db.execute(text(statement))
        await f.migrate_comments(db)
        await f.migrate_comments(db)
        assert (await db.execute(text('SELECT content,reply_to_id,is_deleted FROM post_comments'))).one()==('Existing comment',None,0)
        assert (await db.execute(text('SELECT comment_post_id FROM messages WHERE id=101'))).scalar()==100
        await feed_polls.migrate(db);await feed_polls.migrate(db)
        assert (await db.execute(text('SELECT content,interactive_json FROM posts'))).one()==('Existing post',None)
    await legacy.dispose()
    checks.append('legacy additive migration preserves comments and backfills channel roots; repeatable')
    for task in list(f._tasks):
        task.cancel()
    if f._tasks: await asyncio.gather(*f._tasks,return_exceptions=True)
    await engine.dispose()
    print(json.dumps({'passed':len(checks),'checks':checks},ensure_ascii=False))

asyncio.run(main())
