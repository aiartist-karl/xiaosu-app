"""
小酥APP P2功能路由 - 多Agent协作 + 项目管理 + TTS
"""
import json
import uuid
import os
import time
import logging
import sqlite3
from datetime import datetime
from typing import Optional, List

from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

import config

logger = logging.getLogger("xiaosu.p2")

router = APIRouter()

# ==================== 数据模型 ====================
class AgentCreateRequest(BaseModel):
    id: Optional[str] = None
    name: str
    description: str = ""
    system_prompt: str = ""

class AgentTaskRequest(BaseModel):
    title: str
    task_id: Optional[str] = None

class ProjectCreateRequest(BaseModel):
    id: Optional[str] = None
    name: str
    type: str = "web_app"
    description: str = ""

class ProjectFileRequest(BaseModel):
    path: str
    content: str

class TtsRequest(BaseModel):
    text: str
    voice: str = "female_1"
    speed: float = 1.0


def init_p2_db():
    """初始化P2功能的数据库表"""
    db_path = config.DB_PATH
    with sqlite3.connect(db_path) as conn:
        conn.execute("""CREATE TABLE IF NOT EXISTS agents (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT DEFAULT '',
            system_prompt TEXT DEFAULT '', status TEXT DEFAULT 'idle',
            task_count INTEGER DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)""")
        conn.execute("""CREATE TABLE IF NOT EXISTS agent_tasks (
            id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, title TEXT NOT NULL,
            status TEXT DEFAULT 'pending', result TEXT DEFAULT '',
            created_at TEXT NOT NULL, completed_at TEXT,
            FOREIGN KEY (agent_id) REFERENCES agents(id))""")
        conn.execute("""CREATE TABLE IF NOT EXISTS projects (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT DEFAULT 'web_app',
            status TEXT DEFAULT 'active', description TEXT DEFAULT '',
            file_count INTEGER DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)""")
        conn.execute("""CREATE TABLE IF NOT EXISTS project_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT, project_id TEXT NOT NULL,
            path TEXT NOT NULL, content TEXT DEFAULT '', updated_at TEXT NOT NULL,
            FOREIGN KEY (project_id) REFERENCES projects(id))""")
        conn.commit()
    logger.info("P2 DB initialized")


async def verify_token(request: Request) -> str:
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        token = request.query_params.get("token", "")
        if not token:
            raise HTTPException(status_code=401, detail="Missing token")
    else:
        token = auth_header[7:]
    if token not in config.AUTH_TOKENS:
        raise HTTPException(status_code=403, detail="Invalid token")
    return token


# ==================== Agent API ====================

@router.get("/api/agents")
async def list_agents(token: str = Depends(verify_token)):
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute("SELECT * FROM agents ORDER BY created_at DESC").fetchall()
        agents = [dict(row) for row in rows]
    return {"agents": agents, "total": len(agents)}


@router.post("/api/agents")
async def create_agent(req: AgentCreateRequest, token: str = Depends(verify_token)):
    agent_id = req.id or f"agent_{uuid.uuid4().hex[:8]}"
    now = datetime.now().isoformat()
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.execute("INSERT INTO agents (id,name,description,system_prompt,status,task_count,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)",
            (agent_id, req.name, req.description, req.system_prompt, "idle", 0, now, now))
        conn.commit()
    logger.info(f"Created agent: {agent_id}")
    return {"success": True, "agent_id": agent_id}


@router.delete("/api/agents/{agent_id}")
async def delete_agent(agent_id: str, token: str = Depends(verify_token)):
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.execute("DELETE FROM agent_tasks WHERE agent_id = ?", (agent_id,))
        conn.execute("DELETE FROM agents WHERE id = ?", (agent_id,))
        conn.commit()
    return {"success": True}


@router.get("/api/agent/{agent_id}/tasks")
async def list_agent_tasks(agent_id: str, token: str = Depends(verify_token)):
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute("SELECT * FROM agent_tasks WHERE agent_id = ? ORDER BY created_at DESC", (agent_id,)).fetchall()
        tasks = [dict(row) for row in rows]
    return {"tasks": tasks, "total": len(tasks)}


@router.post("/api/agent/{agent_id}/task")
async def dispatch_task(agent_id: str, req: AgentTaskRequest, token: str = Depends(verify_token)):
    task_id = req.task_id or f"task_{uuid.uuid4().hex[:8]}"
    now = datetime.now().isoformat()
    with sqlite3.connect(config.DB_PATH) as conn:
        agent = conn.execute("SELECT id,name FROM agents WHERE id = ?", (agent_id,)).fetchone()
        if not agent:
            raise HTTPException(status_code=404, detail=f"Agent not found: {agent_id}")
        conn.execute("INSERT INTO agent_tasks (id,agent_id,title,status,created_at) VALUES (?,?,?,?,?)",
            (task_id, agent_id, req.title, "running", now))
        conn.execute("UPDATE agents SET status='active', task_count=task_count+1, updated_at=? WHERE id=?", (now, agent_id))
        conn.commit()

    import asyncio
    async def simulate():
        await asyncio.sleep(3)
        with sqlite3.connect(config.DB_PATH) as conn:
            conn.execute("UPDATE agent_tasks SET status='completed', result=?, completed_at=? WHERE id=?",
                (f"Task '{req.title}' done", datetime.now().isoformat(), task_id))
            conn.commit()
    asyncio.create_task(simulate())
    return {"success": True, "task_id": task_id, "status": "running"}


# ==================== Projects API ====================

@router.get("/api/projects")
async def list_projects(token: str = Depends(verify_token)):
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute("SELECT * FROM projects ORDER BY updated_at DESC").fetchall()
        projects = [dict(row) for row in rows]
    return {"projects": projects, "total": len(projects)}


@router.post("/api/projects")
async def create_project(req: ProjectCreateRequest, token: str = Depends(verify_token)):
    project_id = req.id or f"proj_{uuid.uuid4().hex[:8]}"
    now = datetime.now().isoformat()
    project_dir = f"/opt/xiaosu-backend/templates/{project_id}"
    os.makedirs(f"{project_dir}/src", exist_ok=True)
    _init_template(project_dir, req.type, req.name)
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.execute("INSERT INTO projects (id,name,type,status,description,file_count,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)",
            (project_id, req.name, req.type, "active", req.description, 0, now, now))
        conn.commit()
    return {"success": True, "project_id": project_id}


@router.get("/api/projects/{project_id}")
async def get_project(project_id: str, token: str = Depends(verify_token)):
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute("SELECT * FROM projects WHERE id = ?", (project_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Project not found")
        project = dict(row)
        files = conn.execute("SELECT path FROM project_files WHERE project_id = ?", (project_id,)).fetchall()
        project["files"] = [{"name": f["path"].split("/")[-1], "is_directory": False, "path": f["path"]} for f in files]
    project["build_logs"] = [f"[{datetime.now().strftime('%H:%M:%S')}] Project ready"]
    return project


@router.post("/api/projects/{project_id}/file")
async def save_file(project_id: str, req: ProjectFileRequest, token: str = Depends(verify_token)):
    now = datetime.now().isoformat()
    project_dir = f"/opt/xiaosu-backend/templates/{project_id}"
    file_path = os.path.join(project_dir, req.path)
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(req.content)
    with sqlite3.connect(config.DB_PATH) as conn:
        existing = conn.execute("SELECT id FROM project_files WHERE project_id=? AND path=?", (project_id, req.path)).fetchone()
        if existing:
            conn.execute("UPDATE project_files SET content=?, updated_at=? WHERE project_id=? AND path=?", (req.content, now, project_id, req.path))
        else:
            conn.execute("INSERT INTO project_files (project_id,path,content,updated_at) VALUES (?,?,?,?)", (project_id, req.path, req.content, now))
            conn.execute("UPDATE projects SET file_count=(SELECT COUNT(*) FROM project_files WHERE project_id=?), updated_at=? WHERE id=?", (project_id, now, project_id))
        conn.commit()
    return {"success": True}


@router.post("/api/projects/{project_id}/build")
async def build_project(project_id: str, token: str = Depends(verify_token)):
    now = datetime.now().isoformat()
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.execute("UPDATE projects SET status='building', updated_at=? WHERE id=?", (now, project_id))
        conn.commit()
    import asyncio
    async def simulate():
        await asyncio.sleep(5)
        with sqlite3.connect(config.DB_PATH) as conn:
            conn.execute("UPDATE projects SET status='active', updated_at=? WHERE id=?", (datetime.now().isoformat(), project_id))
            conn.commit()
    asyncio.create_task(simulate())
    return {"success": True, "message": "Build triggered"}


# ==================== TTS API ====================

@router.post("/api/tts")
async def tts_synthesize(req: TtsRequest, token: str = Depends(verify_token)):
    if not req.text or not req.text.strip():
        raise HTTPException(status_code=400, detail="Text required")
    audio_id = f"tts_{uuid.uuid4().hex[:12]}"
    audio_dir = "/opt/xiaosu-backend/audio"
    os.makedirs(audio_dir, exist_ok=True)
    logger.info(f"TTS: text='{req.text[:50]}...' voice={req.voice}")
    audio_url = f"http://47.116.29.140/agent/audio/{audio_id}.mp3"
    return {"success": True, "url": audio_url, "audio_id": audio_id}


# ==================== Template Init ====================

def _init_template(project_dir: str, project_type: str, name: str):
    src = os.path.join(project_dir, "src")
    if project_type == "web_app":
        with open(os.path.join(src, "index.html"), "w") as f:
            f.write(f'<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>{name}</title><link rel="stylesheet" href="app.css"></head><body><div id="app"><h1>{name}</h1></div><script type="module" src="main.js"></script></body></html>')
        with open(os.path.join(src, "main.js"), "w") as f:
            f.write('console.log("App started");\n')
        with open(os.path.join(src, "app.css"), "w") as f:
            f.write('* { margin:0; padding:0; box-sizing:border-box; }\nbody { font-family:sans-serif; background:#f5f5f5; }\n')
        with open(os.path.join(project_dir, "package.json"), "w") as f:
            json.dump({"name": name.lower().replace(" ","-"), "version": "1.0.0", "main": "src/main.js"}, f, indent=2)
    elif project_type == "mini_app":
        with open(os.path.join(src, "app.js"), "w") as f:
            f.write('App({onLaunch(){console.log("launch");}});\n')
        with open(os.path.join(src, "app.json"), "w") as f:
            json.dump({"pages":["pages/index/index"],"window":{"navigationBarTitleText":name}}, f, indent=2)
    elif project_type == "android_app":
        with open(os.path.join(src, "MainActivity.java"), "w") as f:
            f.write(f'package com.xiaosu.{name.lower().replace(" ","")};\nimport android.app.Activity;\nimport android.os.Bundle;\npublic class MainActivity extends Activity {{\n  @Override protected void onCreate(Bundle s) {{ super.onCreate(s); }}\n}}\n')
    with open(os.path.join(project_dir, "README.md"), "w") as f:
        f.write(f"# {name}\n\n由小酥APP创建\n")
