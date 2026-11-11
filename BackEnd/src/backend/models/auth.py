from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator


class RegisterIn(BaseModel):
    role: Literal["USER", "TECHNICIAN"]
    name: str
    email: EmailStr
    phone: str = Field(min_length=8)
    password: str = Field(min_length=8)
    city: str
    district: str
    skills: list[str] | None = None
    terms_accepted: bool = False

    model_config = {"extra": "forbid"}

    @field_validator("email")
    @classmethod
    def lower_email(cls, v: EmailStr) -> EmailStr:
        return v.strip().lower()

    @model_validator(mode="after")
    def technician_attribute_validator(self) -> "RegisterIn":
        if self.role == "TECHNICIAN":
            if not self.skills:
                raise ValueError("Attribute skills wajib diisi untuk role TECHNICIAN")
            if not self.terms_accepted:
                raise ValueError(
                    "Attribute terms_accepted wajib berisi nilai True untuk role TECHNICIAN"
                )
        return self


class RegisterOut(BaseModel):
    pass


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class LoginOut(BaseModel):
    pass


class UserOut(BaseModel):
    id: str = Field(alias="_id")
    role: Literal["USER", "TECHNICIAN"]
    name: str
    email: EmailStr
    phone: str
    avatar_url: str | None = None

    model_config = {"extra": "ignore"}


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut
    needs_phone: bool
