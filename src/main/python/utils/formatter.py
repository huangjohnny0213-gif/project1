from rich.console import Console
from rich.table import Table
from rich import box

console = Console()

INTENT_COLORS = {
    "Informational": "cyan",
    "Commercial": "yellow",
    "Transactional": "green",
    "Navigational": "blue",
}

DIFFICULTY_COLORS = {
    "Low": "green",
    "Medium": "yellow",
    "High": "red",
}

VOLUME_COLORS = {
    "Low <1K": "dim",
    "Medium 1K-10K": "yellow",
    "High >10K": "green",
}


def display_results(seed_keyword: str, keywords: list[dict]) -> None:
    console.print(f"\n[bold]Keyword Research:[/bold] [cyan]{seed_keyword}[/cyan]\n")

    table = Table(box=box.ROUNDED, show_lines=True, expand=True)
    table.add_column("#", style="dim", width=3, justify="right")
    table.add_column("Keyword", style="bold white", min_width=25)
    table.add_column("Intent", min_width=14, justify="center")
    table.add_column("Difficulty", min_width=10, justify="center")
    table.add_column("Volume", min_width=14, justify="center")
    table.add_column("Content Angle", min_width=35)

    for i, kw in enumerate(keywords, 1):
        intent = kw.get("intent", "")
        difficulty = kw.get("difficulty", "")
        volume = kw.get("volume", "")

        intent_styled = f"[{INTENT_COLORS.get(intent, 'white')}]{intent}[/]"
        difficulty_styled = f"[{DIFFICULTY_COLORS.get(difficulty, 'white')}]{difficulty}[/]"
        volume_styled = f"[{VOLUME_COLORS.get(volume, 'white')}]{volume}[/]"

        table.add_row(
            str(i),
            kw.get("keyword", ""),
            intent_styled,
            difficulty_styled,
            volume_styled,
            kw.get("content_angle", ""),
        )

    console.print(table)
    console.print(f"\n[dim]Total keywords: {len(keywords)}[/dim]\n")
