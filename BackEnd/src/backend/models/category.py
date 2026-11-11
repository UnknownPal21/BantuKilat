from pydantic import BaseModel, Field


class CategoryOut(BaseModel):
    id: str = Field(alias="_id")
    code: str
    label: str
    skill_label: str
    icon: str
    short_desc: str
    color: str | None = None
    sort: int
