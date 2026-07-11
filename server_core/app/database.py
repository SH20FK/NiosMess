from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import StaticPool
from app.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
    echo=False,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)


async def init_db():
    from app.migrations import run_migrations
    await run_migrations()
    # Ensure botcreator account exists
    async with AsyncSessionLocal() as session:
        from app.services.bot_svc import ensure_botcreator
        await ensure_botcreator(session)
        await session.commit()


async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
