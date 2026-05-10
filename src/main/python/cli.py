import click
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

from .core.keyword_researcher import research_keywords
from .utils.formatter import display_results
from .utils.exporter import export_to_csv

console = Console()


@click.group()
def cli():
    """AI SEO Tool — keyword research powered by Claude."""
    pass


@cli.command()
@click.argument("keyword")
@click.option("--count", "-n", default=15, show_default=True, help="Number of keywords to generate.")
@click.option("--export", "-e", is_flag=True, help="Export results to CSV in output/.")
def research(keyword: str, count: int, export: bool):
    """Research keyword suggestions for a seed KEYWORD."""
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        transient=True,
    ) as progress:
        progress.add_task(f"Researching '{keyword}'...", total=None)
        try:
            keywords = research_keywords(keyword, count)
        except Exception as e:
            console.print(f"[red]Error:[/red] {e}")
            raise SystemExit(1)

    display_results(keyword, keywords)

    if export:
        path = export_to_csv(keyword, keywords)
        console.print(f"[green]Exported to:[/green] {path}\n")


if __name__ == "__main__":
    cli()
