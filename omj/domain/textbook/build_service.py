"""Textbook build service.

Provides:
- TextbookBuilderService: orchestrates AI-powered textbook block generation
  and persists jobs via JobStateMachine (A11).
"""
from typing import Optional

from domain.textbook.models import TextbookBlock, TextbookBuildRequest, TextbookBuildResult, TextbookGraph
from services.ai.providers.base import AIProvider
from services.jobs.state_machine import JobStateMachine


class TextbookBuilderService:
    """Orchestrates AI generation of textbook blocks."""

    def __init__(self, ai_provider: AIProvider):
        self._ai_provider = ai_provider
        self._job_machine = JobStateMachine()

    def start_build(self, request: TextbookBuildRequest) -> TextbookBuildResult:
        """Enqueue a build job and return a job handle."""
        payload = {
            "course_id": request.course_id,
            "root_ids": request.root_ids,
            "ai_provider": request.ai_provider,
        }
        state = self._job_machine.start_job(
            user_id="system",
            job_type="textbook_build",
            payload=payload,
        )
        return TextbookBuildResult(
            job_id=state["job_id"],
            status=state["status"],
            blocks_generated=0,
            preview_url=None,
        )

    def build_blocks_sync(self, graph: TextbookGraph) -> list[TextbookBlock]:
        """Synchronous demo: generate content for each root block via AI."""
        generated: list[TextbookBlock] = []
        for block_id in graph.root_blocks:
            # Build a minimal block for prompt generation
            block = TextbookBlock(
                id=block_id,
                type="section",
                title=f"Block {block_id}",
                level=1,
            )
            prompt = self.prompt_for_block(block)
            result = self._ai_provider.generate(prompt)
            content = result.get("text", "")
            generated.append(
                TextbookBlock(
                    id=block_id,
                    type=block.type,
                    title=block.title,
                    content=content,
                    level=block.level,
                )
            )
        return generated

    @staticmethod
    def prompt_for_block(block: TextbookBlock) -> str:
        """Create a Korean-language prompt for generating learning content."""
        return (
            f"다음 블록에 대한 학습 콘텐츠를 생성하세요: "
            f"{block.title} (유형: {block.type}, 수준: {block.level})"
        )
