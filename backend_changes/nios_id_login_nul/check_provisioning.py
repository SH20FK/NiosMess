import asyncio,json,bcrypt
from unittest.mock import patch,AsyncMock
from sqlalchemy import select,func
from sqlalchemy.ext.asyncio import create_async_engine,async_sessionmaker
from app.models.models import Base,User,Session
from app.services import nios_id_svc as svc
from app.ws.handlers import auth_handler

async def main():
 engine=create_async_engine('sqlite+aiosqlite:///:memory:')
 checks=[]
 try:
  async with engine.begin() as c:await c.run_sync(Base.metadata.create_all)
  factory=async_sessionmaker(engine,expire_on_commit=False)
  async with factory() as db:
   claims=svc.NiosIdentityClaims(sub='nios_synthetic_nul_regression',name='Synthetic',email='nul-fixture@example.invalid',email_verified=True,status='active')
   # Deterministically reproduce the old generator with the installed bcrypt.
   with patch.object(svc.secrets,'token_bytes',side_effect=lambda n:bytes(n)):
    try:bcrypt.hashpw(svc.secrets.token_bytes(48),bcrypt.gensalt())
    except ValueError as error:assert 'NUL' in str(error)
    else:raise AssertionError('Original failure was not reproduced')
    with patch.object(auth_handler,'resolve_nios_oauth_token',new=AsyncMock(return_value=claims)):
     result=await auth_handler.handle_nios_id_login({'oauth_access_token':'synthetic-fixture'},db)
   assert result['profile_created'] is True and result['user_id']>0
   checks.append('original NUL failure reproduced; new profile and session succeed with zero-valued random bytes')
   profile=await db.scalar(select(User).where(User.id==result['user_id']))
   assert bcrypt.checkpw(b'A'*64,profile.hashed_password.encode())
   checks.append('technical password is 64 ASCII bytes with full random source length')
   with patch.object(auth_handler,'resolve_nios_oauth_token',new=AsyncMock(return_value=claims)):
    again=await auth_handler.handle_nios_id_login({'oauth_access_token':'synthetic-fixture'},db)
   assert again['profile_created'] is False and again['user_id']==result['user_id']
   assert again['access_token']!=result['access_token']
   assert await db.scalar(select(func.count()).select_from(User))==1
   checks.append('existing profile is reused; distinct sessions are created')
   with patch.object(auth_handler,'resolve_nios_oauth_token',new=AsyncMock(return_value=None)):
    assert 'error' in await auth_handler.handle_nios_id_login({'oauth_access_token':'invalid-fixture'},db)
   assert 'error' in await auth_handler.handle_nios_id_login({},db)
   checks.append('invalid or missing OAuth token still rejected')
   collision=svc.NiosIdentityClaims(sub='nios_other_synthetic',name='Other',email=claims.email,email_verified=True,status='active')
   try:await svc.get_or_create_nios_profile(db,collision)
   except RuntimeError:pass
   else:raise AssertionError('Email collision auto-linked')
   checks.append('email collision never auto-links another account')
   for verified,status in ((False,'active'),(True,'blocked')):
    bad=svc.NiosIdentityClaims(sub='nios_ineligible',name='Other',email='ineligible@example.invalid',email_verified=verified,status=status)
    try:await svc.get_or_create_nios_profile(db,bad)
    except RuntimeError:pass
    else:raise AssertionError('Ineligible profile created')
   checks.append('unverified and inactive identities remain rejected')
 finally:await engine.dispose()
 print(json.dumps({'checks':checks,'count':len(checks),'real_accounts_used':0}))
asyncio.run(main())
