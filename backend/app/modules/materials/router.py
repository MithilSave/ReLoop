"""Materials module router."""

from typing import List, Optional
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.reference import MaterialCategory

router = APIRouter(tags=["materials"])


class MaterialCategoryOut(BaseModel):
    id: int
    code: str
    name: str
    resin_code: Optional[int] = None
    default_packaging_category: Optional[str] = None
    description: Optional[str] = None

    class Config:
        from_attributes = True


@router.get("/materials", response_model=List[MaterialCategoryOut])
async def list_materials(db: AsyncSession = Depends(get_db)):
    stmt = select(MaterialCategory).order_by(MaterialCategory.id.asc())
    res = await db.execute(stmt)
    return res.scalars().all()
