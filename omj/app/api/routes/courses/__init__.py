"""Course V2 routers package."""
from app.api.routes.courses.router import router as course_v2_router
from app.api.routes.courses.ai_proposal_router import router as ai_proposal_router
from app.api.routes.courses.runtime_router import router as runtime_router

__all__ = ["course_v2_router", "ai_proposal_router", "runtime_router"]
