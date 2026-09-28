import discord
from discord.ext import commands
from discord import app_commands
import aiohttp
import tempfile
import subprocess
import asyncio
from pathlib import Path

intents = discord.Intents.default()
intents.message_content = True

bot = commands.Bot(command_prefix="!", intents=intents)

DUMPER_DIR = Path(__file__).parent / "Luraph_Dumper"
DUMPER_SCRIPT = DUMPER_DIR / "dumper.py"

@bot.event
async def on_ready():
    print(f"Bot ready as {bot.user}")
    await bot.tree.sync()
    print("Commands synced")

async def fetch_content(url_or_content: str) -> tuple[str, str]:
    content = url_or_content.strip()
    
    if content.startswith("```") and content.endswith("```"):
        lines = content.split("\n")
        if len(lines) > 2:
            return "\n".join(lines[1:-1]), "codeblock"
        return content[3:-3], "codeblock"
    
    if content.startswith(("http://", "https://", "github.com", "pastebin.com", "raw.")):
        if "github.com" in content and "/blob/" in content:
            content = content.replace("/blob/", "/raw/")
        
        if not content.startswith("http"):
            if "raw." in content:
                content = f"https://{content}"
            else:
                content = f"https://{content}"
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(content, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                    if resp.status == 200:
                        data = await resp.text()
                        return data, "url"
                    else:
                        return None, f"HTTP {resp.status}"
        except Exception as e:
            return None, str(e)
    
    return content, "raw"

async def run_dumper(lua_content: str) -> tuple[str, bool]:
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".lua", delete=False, encoding="utf-8") as f:
            f.write(lua_content)
            input_path = f.name
        
        input_path_obj = Path(input_path)
        
        cmd = [
            "python",
            str(DUMPER_SCRIPT),
            input_path
        ]
        
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(DUMPER_DIR)
        )
        
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=60)
        
        output_path = input_path_obj.parent / f"{input_path_obj.stem}-output.lua"
        
        if output_path.exists() and output_path.stat().st_size > 0:
            with open(output_path, "r", encoding="utf-8") as f:
                result = f.read()
            
            try:
                input_path_obj.unlink()
                output_path.unlink()
            except:
                pass
            
            return result, True
        else:
            error_msg = stderr.decode("utf-8", errors="ignore") if stderr else "Unknown error"
            return error_msg, False
    
    except asyncio.TimeoutError:
        return "Timeout", False
    except Exception as e:
        return str(e), False

@bot.tree.command(name="dump", description="Dump and deobfuscate Lua code")
@app_commands.describe(
    file="Raw link, URL, or Lua code",
    attachment="Upload a .lua, .txt, or .luau file"
)
async def dump_command(interaction: discord.Interaction, file: str = None, attachment: discord.Attachment = None):
    if not isinstance(interaction.channel, discord.DMChannel):
        await interaction.response.send_message("This command only works in DMs", ephemeral=True)
        return
    
    await interaction.response.defer()
    
    if attachment:
        if not attachment.filename.endswith((".lua", ".txt", ".luau")):
            await interaction.followup.send(f"Invalid file type: {attachment.filename}. Use .lua, .txt, or .luau")
            return
        try:
            content = await attachment.read()
            content = content.decode("utf-8", errors="ignore")
            source = "file"
        except Exception as e:
            await interaction.followup.send(f"Failed to read file: {e}")
            return
    elif file:
        content, source = await fetch_content(file)
    else:
        await interaction.followup.send("Provide either a file attachment or text/link input")
        return
    
    if content is None:
        await interaction.followup.send(f"Failed to fetch: {source}")
        return
    
    if not any(keyword in content for keyword in ["function", "local", "return", "if", "for", "while", "do", "end", "--"]):
        if len(content) > 200:
            await interaction.followup.send("Content doesn't look like Lua. Attempting dump anyway...")
        else:
            await interaction.followup.send("Content doesn't appear to be Lua code")
            return
    
    result, success = await run_dumper(content)
    
    if success:
        if len(result) <= 2000:
            await interaction.followup.send(f"```lua\n{result}\n```")
        else:
            with tempfile.NamedTemporaryFile(mode="w", suffix=".lua", delete=False, encoding="utf-8") as f:
                f.write(result)
                temp_path = f.name
            
            try:
                await interaction.followup.send(file=discord.File(temp_path, "dumped.lua"))
            finally:
                Path(temp_path).unlink()
    else:
        await interaction.followup.send(f"Dump failed:\n```\n{result[:500]}\n```")

if __name__ == "__main__":
    TOKEN = "MTU1MzY5OTU2Nzk2OTYzNjM1Mg.GJswS1.HWlhNQRME3T51kzAcGlKrq5dDjD2U4ZKt30W_A"
    bot.run(TOKEN)
