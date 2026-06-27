import os
import logging
import base64
import json
import time
from pathlib import Path
from typing import Optional
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import httpx

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Always load Backend/.env regardless of the process working directory
_BACKEND_DIR = Path(__file__).resolve().parent
load_dotenv(dotenv_path=_BACKEND_DIR / ".env")

app = FastAPI(
    title="Prompt Generator Backend",
    description="Groq API proxy for the Master Prompt Generator website"
)

# Enable CORS for Flutter Web local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Fetch Groq API Key
GROQ_API_KEY = os.getenv("GROQ_API_KEY") or os.getenv("API_KEY")


def _api_key_status() -> dict:
    return {
        "backend_ok": True,
        "api_key_configured": bool(GROQ_API_KEY),
        "env_file": str(_BACKEND_DIR / ".env"),
    }


@app.get("/api/health")
async def health_check():
    status = _api_key_status()
    if not status["api_key_configured"]:
        return {
            **status,
            "ready": False,
            "message": "GROQ_API_KEY or API_KEY not found in Backend/.env",
        }
    return {**status, "ready": True, "message": "Backend ready"}


def decode_jwt_payload(token: str) -> Optional[dict]:
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        payload_b64 = parts[1]
        payload_b64 += "=" * ((4 - len(payload_b64) % 4) % 4)
        payload_bytes = base64.b64decode(payload_b64)
        return json.loads(payload_bytes.decode("utf-8"))
    except Exception as e:
        logger.error(f"Error decoding JWT payload: {e}")
        return None

def verify_auth_gatekeeper(authorization: Optional[str], x_trial_request: Optional[str]):
    if authorization:
        parts = authorization.split(" ")
        if len(parts) != 2 or parts[0].lower() != "bearer":
            raise HTTPException(status_code=401, detail="Invalid Authorization header format. Use 'Bearer <token>'.")
        
        token = parts[1]
        payload = decode_jwt_payload(token)
        if not payload:
            raise HTTPException(status_code=401, detail="Invalid authentication token.")
        
        # Check expiration
        exp = payload.get("exp")
        if exp and exp < time.time():
            raise HTTPException(status_code=401, detail="Session expired. Please sign in again.")
            
        logger.info(f"Request authorized for user: {payload.get('email', 'unknown')}")
        return payload
    else:
        if x_trial_request == "true":
            logger.info("Anonymous single sandbox interaction cycle allowed.")
            return None
        else:
            raise HTTPException(
                status_code=401,
                detail="Trial limit reached. Authentication required to perform this action."
            )


class PromptRequest(BaseModel):
    raw_input: str
    tone: str
    detail_level: str
    length_constraint: str

@app.post("/api/generate-prompt")
async def generate_prompt(
    request: PromptRequest,
    authorization: Optional[str] = Header(None),
    x_trial_request: Optional[str] = Header(None)
):
    verify_auth_gatekeeper(authorization, x_trial_request)
    logger.info(f"Received generation request: {request.raw_input[:50]}...")
    
    if not GROQ_API_KEY:
        logger.error("Groq API key not found in Backend/.env file.")
        raise HTTPException(
            status_code=500,
            detail="GROQ_API_KEY or API_KEY not found in backend .env file. Please add your Groq key."
        )
    
    # System prompt directing the AI to generate a highly optimized "Master Prompt"
    system_instruction = (
        "You are an expert Prompt Engineer. Your task is to take a user's rough idea "
        "or description of a task/role and generate a highly optimized 'Master Prompt' "
        "that the user can copy and paste into other AI models (like ChatGPT, Gemini, or Claude) "
        "to perform that task.\n\n"
        "Format the Master Prompt in beautiful Markdown using the following structure:\n\n"
        "# ROLE\n"
        "[Specify the precise role, persona, and expertise required. Start with: 'Act as...']\n\n"
        "# CONTEXT\n"
        "[Provide the necessary background information, setting, or target audience]\n\n"
        "# TASK\n"
        "[Clearly outline the primary instructions, goals, and assignments]\n\n"
        "# CONSTRAINTS & RULES\n"
        "- [Constraint 1]\n"
        "- [Constraint 2]\n"
        "- [Constraint 3]\n\n"
        "# STYLISTIC GUIDELINES\n"
        "- Tone: [Tone]\n"
        "- Detail: [Detail Level]\n"
        "- Formatting: [Formatting style like bullet points, tables, code blocks, etc.]\n\n"
        "# INPUT PLACEHOLDERS\n"
        "[List any variables in brackets (like [INPUT_TEXT]) that the user needs to provide when using this prompt]"
    )

    user_message = (
        f"User Prompt/Task Description: \"{request.raw_input}\"\n"
        f"Desired Persona Tone: {request.tone}\n"
        f"Desired Detail Level: {request.detail_level}\n"
        f"Desired Output Length: {request.length_constraint}"
    )

    headers = {
        "Authorization": f"Bearer {GROQ_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "llama-3.3-70b-versatile",
        "messages": [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": user_message}
        ],
        "temperature": 0.7,
        "max_tokens": 4096
    }

    async with httpx.AsyncClient() as client:
        try:
            logger.info("Sending request to Groq API...")
            response = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers=headers,
                json=payload,
                timeout=45.0
            )
            
            if response.status_code != 200:
                logger.error(f"Groq API returned status code {response.status_code}: {response.text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Groq API error: {response.text}"
                )
            
            data = response.json()
            master_prompt = data["choices"][0]["message"]["content"].strip()
            logger.info("Master prompt successfully generated.")
            return {"master_prompt": master_prompt}
            
        except httpx.RequestError as exc:
            logger.error(f"HTTP request failed: {exc}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to communicate with Groq API: {exc}"
            )

class TemplateSpecRequest(BaseModel):
    idea: str

@app.post("/api/generate-template-spec")
async def generate_template_spec(
    request: TemplateSpecRequest,
    authorization: Optional[str] = Header(None),
    x_trial_request: Optional[str] = Header(None)
):
    verify_auth_gatekeeper(authorization, x_trial_request)
    logger.info(f"Received template spec request: {request.idea[:50]}...")
    
    if not GROQ_API_KEY:
        logger.error("Groq API key not found in Backend/.env file.")
        raise HTTPException(
            status_code=500,
            detail="GROQ_API_KEY or API_KEY not found in backend .env file. Please add your Groq key."
        )

    system_instruction = (
        "You are an expert UI/UX Template Architect.\n"
        "Your sole purpose is to generate high-quality, high-fidelity UI template ideas based on the user's requirements.\n"
        "When a user describes a product, business, app, website, dashboard, platform, or feature, analyze the request and generate multiple UI template concepts.\n\n"
        "For every request:\n"
        "1. Identify the product type.\n"
        "2. Identify the target audience.\n"
        "3. Identify the primary user goals.\n"
        "4. Generate 5 unique UI template ideas.\n"
        "5. Make each template visually distinct.\n"
        "6. Follow modern UI/UX best practices.\n"
        "7. Focus on layouts that can realistically be built with React, Next.js, Tailwind CSS, Shadcn UI, Material UI, or similar frameworks.\n"
        "8. Generate detailed AI prompts suitable for UI generation tools.\n\n"
        "Return ONLY valid JSON. Do not include markdown or wrap JSON in code blocks.\n\n"
        "JSON Schema:\n"
        "{\n"
        "  \"projectType\": \"\",\n"
        "  \"targetAudience\": \"\",\n"
        "  \"recommendedStyle\": \"\",\n"
        "  \"templates\": [\n"
        "    {\n"
        "      \"id\": \"\",\n"
        "      \"name\": \"\",\n"
        "      \"style\": \"\",\n"
        "      \"description\": \"\",\n"
        "      \"bestFor\": \"\",\n"
        "      \"layout\": {\n"
        "        \"header\": \"\",\n"
        "        \"sidebar\": \"\",\n"
        "        \"navigation\": \"\",\n"
        "        \"heroSection\": \"\",\n"
        "        \"contentSections\": [],\n"
        "        \"footer\": \"\"\n"
        "      },\n"
        "      \"components\": [],\n"
        "      \"colorPalette\": {\n"
        "        \"primary\": \"\",\n"
        "        \"secondary\": \"\",\n"
        "        \"accent\": \"\",\n"
        "        \"background\": \"\"\n"
        "      },\n"
        "      \"generationPrompt\": \"\"\n"
        "    }\n"
        "  ]\n"
        "}\n\n"
        "Rules:\n"
        "- Always generate exactly 5 template ideas.\n"
        "- Every template must be different.\n"
        "- Use modern design trends.\n"
        "- Include realistic UI components.\n"
        "- Create highly detailed generation prompts.\n"
        "- STRICTLY AVOID generic descriptions like 'Simple with navigation', 'Standard navbar', 'Hero section with background image', 'Simple footer', 'About section', 'Feature 1', 'Feature 2', etc. All fields must be highly themed and contextual to the user's prompt.\n"
        "- For example, if the prompt is for a space-themed UI, the header should be something like 'Telemetry navigation bar with planetary coordinate dials', the hero should be 'Holographic star system orbit simulator overlay', and the content sections should detail specific telemetry widgets, stellar spectroscopy graphs, and celestial database logs.\n"
        "- Ensure color palettes are high-fidelity, aesthetic, and themed (e.g. for space apps, use deep space colors like #0B0E14, neon accents, cyan, purple, rather than generic #ffffff and basic gray backgrounds).\n"
        "- Generation prompts must describe: Layout, Typography, Colors, Component placement, User experience, Responsiveness, Visual hierarchy, Design style.\n\n"
        "Template Styles to consider: Minimal SaaS, Enterprise Dashboard, Modern Startup, AI Product, Glassmorphism, Neumorphism, Dark Professional, Fintech, Analytics, Ecommerce, Portfolio, Education, Healthcare.\n\n"
        "Generation prompts should be detailed enough that another AI can directly generate the UI."
    )

    user_message = f"Website Description: \"{request.idea}\""

    headers = {
        "Authorization": f"Bearer {GROQ_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "llama-3.3-70b-versatile",
        "messages": [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": user_message}
        ],
        "temperature": 0.3,
        "max_tokens": 4096,
        "response_format": {"type": "json_object"}
    }

    async with httpx.AsyncClient() as client:
        try:
            logger.info("Sending request to Groq API...")
            response = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers=headers,
                json=payload,
                timeout=45.0
            )
            
            if response.status_code != 200:
                logger.error(f"Groq API returned status code {response.status_code}: {response.text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Groq API error: {response.text}"
                )
            
            data = response.json()
            raw_content = data["choices"][0]["message"]["content"].strip()
            
            import json
            parsed_json = json.loads(raw_content)
            
            # Provide safe fallbacks for keys
            fallback_spec = {
                "projectType": "Web Application",
                "targetAudience": "General Audience",
                "recommendedStyle": "Minimal SaaS",
                "templates": [
                    {
                        "id": "template_1",
                        "name": "Standard Landing Page",
                        "style": "Minimal SaaS",
                        "description": "Clean and professional landing page layout.",
                        "bestFor": "Modern startups and SaaS products",
                        "layout": {
                            "header": "Clean navbar with logo, pricing links, and CTA button",
                            "sidebar": "None",
                            "navigation": "Horizontal top bar",
                            "heroSection": "Centered bold heading, descriptive paragraph, and primary/secondary button row",
                            "contentSections": ["Feature grid with icons", "Customer testimonials slider", "Simple pricing matrix"],
                            "footer": "Standard 4-column footer with links and social icons"
                        },
                        "components": ["Navbar", "Hero Section", "Feature Cards", "Pricing Table", "Footer"],
                        "colorPalette": {
                            "primary": "#3B82F6",
                            "secondary": "#1E293B",
                            "accent": "#F59E0B",
                            "background": "#F8FAFC"
                        },
                        "generationPrompt": "Create a clean Minimal SaaS landing page with blue primary accents and slate backgrounds."
                    }
                ]
            }
            
            for key, val in fallback_spec.items():
                if key not in parsed_json or not parsed_json[key]:
                    parsed_json[key] = val
                    
            logger.info("Template spec successfully generated.")
            return parsed_json
            
        except Exception as exc:
            logger.error(f"Failed to generate template spec: {exc}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to generate template spec: {str(exc)}"
            )

if __name__ == "__main__":
    import uvicorn
    # Start server locally on port 8000
    uvicorn.run(app, host="127.0.0.1", port=8000)

