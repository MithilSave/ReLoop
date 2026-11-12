"""Reference data models."""

from sqlalchemy import Column, Integer, SmallInteger, String, Text
from app.core.database import Base


class MaterialCategory(Base):
    __tablename__ = "material_categories"

    id = Column(SmallInteger, primary_key=True)
    code = Column(String(32), unique=True, nullable=False, index=True)  # PET, HDPE, PVC, LDPE, PP, PS, OTHER, MLP
    name = Column(String(128), nullable=False)
    resin_code = Column(SmallInteger, nullable=True)  # 1 to 7, None for MLP/OTHER
    default_packaging_category = Column(String(32), nullable=True)  # CAT_I, CAT_II, CAT_III, CAT_IV
    description = Column(Text, nullable=True)
