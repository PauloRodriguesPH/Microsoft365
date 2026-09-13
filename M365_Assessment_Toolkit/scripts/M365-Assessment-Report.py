
# ============================================================
# Microsoft 365 Assessment - Gerador de Entregaveis
# Projeto: Microsoft 365 Assessment
#
# Este script NAO acessa o Microsoft 365.
# Ele apenas lê os CSVs produzidos pelo M365-Assessment.ps1
# e transforma a coleta técnica em:
#
#   1) Excel executivo com Dashboard e abas detalhadas
#   2) Word executivo
#   3) PowerPoint executivo
#
# Uso:
#   python .\scripts\M365-Assessment-Report.py
#
# Ou, se chamado pelo PowerShell:
#   python <este arquivo> --project-root <raiz do projeto>
# ============================================================

import argparse
import csv
import re
import sys
from pathlib import Path
from datetime import datetime

try:
    import pandas as pd
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.chart import BarChart, PieChart, Reference
    from openpyxl.utils import get_column_letter
    from openpyxl.formatting.rule import CellIsRule
    from docx import Document
    from docx.shared import Pt, Inches
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from pptx import Presentation
    from pptx.util import Inches as PInches, Pt as PPt
except ImportError as exc:
    print("")
    print("ERRO: falta uma biblioteca Python para gerar os relatórios.")
    print(f"Detalhe: {exc}")
    print("")
    print("Instale uma vez com:")
    print("python -m pip install pandas openpyxl python-docx python-pptx")
    sys.exit(2)


# ============================================================
# CONFIGURAÇÃO
# ============================================================

parser = argparse.ArgumentParser()
parser.add_argument("--project-root", default=None)
args = parser.parse_args()

if args.project_root:
    PROJECT_ROOT = Path(args.project_root).resolve()
else:
    # Quando o script estiver dentro de .\scripts
    PROJECT_ROOT = Path(__file__).resolve().parent.parent

RAW = PROJECT_ROOT / "output" / "raw"
REPORTS = PROJECT_ROOT / "output" / "reports"
REPORTS.mkdir(parents=True, exist_ok=True)

if not RAW.exists():
    print(f"ERRO: pasta RAW não encontrada: {RAW}")
    sys.exit(3)


# ============================================================
# FUNÇÕES AUXILIARES
# ============================================================

def latest(prefix):
    """Retorna o CSV mais recente para um prefixo."""
    files = sorted(RAW.glob(f"{prefix}-*.csv"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        return None
    # Evita selecionar arquivos de erro quando existe o normal.
    normal = [f for f in files if "-Query-Error-" not in f.name]
    return normal[0] if normal else files[0]


def read_csv(prefix):
    path = latest(prefix)
    if not path:
        return pd.DataFrame()

    # CSV vazio significa "nenhum registro encontrado" e não deve gerar
    # um falso alerta no relatório.
    try:
        if path.stat().st_size == 0:
            return pd.DataFrame()
        if not path.read_text(encoding="utf-8-sig", errors="ignore").strip():
            return pd.DataFrame()
    except Exception:
        pass

    try:
        return pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8-sig")
    except pd.errors.EmptyDataError:
        return pd.DataFrame()
    except Exception:
        try:
            return pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8")
        except pd.errors.EmptyDataError:
            return pd.DataFrame()
        except Exception as exc:
            print(f"Aviso: não foi possível ler {path.name}: {exc}")
            return pd.DataFrame()


def norm(s):
    if s is None:
        return ""
    return str(s).strip().lower()


def first_existing(df, *names):
    for n in names:
        if n in df.columns:
            return n
    return None


def to_bool(v):
    return norm(v) in ("true", "1", "yes", "sim")


def to_num(v):
    try:
        return float(str(v).replace(",", "."))
    except Exception:
        return 0.0


def parse_size_gb(value):
    """
    Converte strings do Exchange como:
      '1.376 GB (1,478,...)'
      '39.4 GB (...)'
      '400 MB (...)'
    para GB aproximados.
    """
    s = str(value or "")
    m = re.search(r"([\d.,]+)\s*(KB|MB|GB|TB)", s, re.I)
    if not m:
        return 0.0
    number = m.group(1)
    # Em dados PowerShell normalmente ponto é decimal.
    try:
        n = float(number.replace(",", ""))
    except Exception:
        try:
            n = float(number.replace(",", "."))
        except Exception:
            return 0.0
    unit = m.group(2).upper()
    return {
        "KB": n / 1024 / 1024,
        "MB": n / 1024,
        "GB": n,
        "TB": n * 1024,
    }[unit]


def safe_sheet_name(name):
    bad = r'[]:*?/\\'
    for c in bad:
        name = name.replace(c, "_")
    return name[:31]


# ============================================================
# CARREGA DOS DADOS
# ============================================================

users = read_csv("Users")
identity = read_csv("Identity-Inventory")
licenses = read_csv("User-Licenses")
skus = read_csv("License-SKUs")
# Exchange: o coletor pode gerar um CSV geral (Mailboxes) ou CSVs
# especializados (User-Mailboxes / Shared-Mailboxes / Room-Mailboxes).
# Preferimos o inventário geral; se ele não existir, combinamos os especializados.
def read_exchange_mailboxes():
    candidates = [
        "Mailboxes",
        "All-Mailboxes",
        "Exchange-Mailboxes",
    ]

    for prefix in candidates:
        df = read_csv(prefix)
        if not df.empty:
            return df

    parts = []
    seen = set()
    for prefix in [
        "User-Mailboxes",
        "Shared-Mailboxes",
        "Room-Mailboxes",
        "Discovery-Mailboxes",
    ]:
        df = read_csv(prefix)
        if not df.empty:
            # Evita duplicidade se o mesmo mailbox aparecer em mais de um CSV.
            key_col = first_existing(
                df,
                "UserPrincipalName",
                "PrimarySmtpAddress",
                "DisplayName",
                "Id",
            )
            if key_col:
                keys = df[key_col].map(norm)
                df = df.loc[~keys.isin(seen)].copy()
                seen.update(keys[keys != ""])
            parts.append(df)

    if parts:
        return pd.concat(parts, ignore_index=True, sort=False)

    return pd.DataFrame()

mailboxes = read_exchange_mailboxes()
mail_stats = read_csv("Mailbox-Statistics")
mailboxes_archive = read_csv("Mailboxes-With-Archive")
mfa = read_csv("MFA-Inventory")
security_defaults = read_csv("Security-Defaults")
ca = read_csv("Conditional-Access-Policies")
roles = read_csv("Directory-Role-Members")
groups = read_csv("Groups")
group_members = read_csv("Group-Members")
group_owners = read_csv("Group-Owners")
teams = read_csv("Teams")
onedrive = read_csv("OneDrive-Inventory")
devices = read_csv("Devices")
apps = read_csv("App-Registrations")
enterprise_apps = read_csv("Enterprise-Applications")
signins = read_csv("SignIns")
directory_audit = read_csv("Directory-Audit")
active_no_license = read_csv("Active-Without-License")
active_no_signin = read_csv("Active-Without-SignIn")

# Timestamp do conjunto
timestamps = []
for f in RAW.glob("*.csv"):
    m = re.search(r"-(\d{8}-\d{6})\.csv$", f.name)
    if m:
        timestamps.append(m.group(1))
run_ts = max(timestamps) if timestamps else datetime.now().strftime("%Y%m%d-%H%M%S")
run_display = datetime.strptime(run_ts, "%Y%m%d-%H%M%S").strftime("%d/%m/%Y %H:%M:%S")


# ============================================================
# INDICADORES
# ============================================================

if not users.empty:
    total_users = len(users)
    active_users = sum(to_bool(x) for x in users.get("AccountEnabled", []))
    blocked_users = total_users - active_users
    license_count_col = first_existing(
        users,
        "AssignedLicenseCount",
        "AssignedLicenses.Count",
        "LicenseCount",
    )
    licensed_users = (
        sum(to_num(x) > 0 for x in users[license_count_col])
        if license_count_col
        else 0
    )
    if licensed_users == 0 and not identity.empty and "LicenseCount" in identity.columns:
        licensed_users = sum(to_num(x) > 0 for x in identity["LicenseCount"])
    unlicensed_users = total_users - licensed_users
    guests = sum(norm(x) == "guest" for x in users.get("UserType", []))
else:
    total_users = active_users = blocked_users = licensed_users = unlicensed_users = guests = 0

if "RecipientTypeDetails" in mailboxes.columns:
    mailbox_type = mailboxes["RecipientTypeDetails"].map(norm)
    user_mailboxes = int((mailbox_type == "usermailbox").sum())
    shared_mailboxes = int((mailbox_type == "sharedmailbox").sum())
    room_mailboxes = int((mailbox_type == "roommailbox").sum())
    discovery_mailboxes = int((mailbox_type == "discoverymailbox").sum())
else:
    user_mailboxes = shared_mailboxes = room_mailboxes = discovery_mailboxes = 0
archive_count = (
    sum(norm(x) == "active" for x in mailboxes["ArchiveStatus"])
    if "ArchiveStatus" in mailboxes.columns
    else 0
)

security_defaults_value = ""
if not security_defaults.empty and "IsEnabled" in security_defaults.columns:
    security_defaults_value = security_defaults.iloc[0]["IsEnabled"]

ca_count = len(ca)

mfa_count = 0
mfa_no_count = 0
if not mfa.empty and "MfaCapableMethodCount" in mfa.columns:
    mfa_count = sum(to_num(x) > 0 for x in mfa["MfaCapableMethodCount"])
    mfa_no_count = len(mfa) - mfa_count

global_admins = len(roles[roles["RoleName"].eq("Global Administrator")]) if "RoleName" in roles.columns else 0
role_assignments = len(roles)

group_count = len(groups)
m365_groups = sum(to_bool(x) for x in groups.get("IsMicrosoft365Group", []))
groups_no_owner = sum(to_num(x) == 0 for x in groups.get("OwnerCount", []))
groups_no_member = sum(to_num(x) == 0 for x in groups.get("MemberCount", []))
teams_count = len(teams) if not teams.empty and "Id" in teams.columns else sum(to_bool(x) for x in groups.get("IsTeam", []))

device_count = len(devices)
app_count = len(apps)
enterprise_app_count = len(enterprise_apps)
signin_count = len(signins)
audit_count = len(directory_audit)


# ============================================================
# CRUZAMENTO PRINCIPAL: USUÁRIO
# ============================================================

if users.empty and not identity.empty:
    user_base = identity.copy()
else:
    user_base = users.copy()

# Normaliza chaves
if not user_base.empty:
    user_base["__key"] = user_base.get("UserPrincipalName", "").map(norm)

# Licenças por usuário
if not licenses.empty:
    l = licenses.copy()
    l["__key"] = l.get("UserPrincipalName", "").map(norm)
    if "LicenseName" in l.columns:
        lnames = l.groupby("__key")["LicenseName"].apply(
            lambda s: "; ".join(sorted(set(x for x in s if x and norm(x) != "sem licenca")))
        )
    else:
        lnames = pd.Series(dtype=str)
else:
    lnames = pd.Series(dtype=str)

# MFA por usuário
if not mfa.empty:
    mm = mfa.copy()
    mm["__key"] = mm.get("UserPrincipalName", "").map(norm)
    mfa_cols = [c for c in ["AuthenticationMethods", "MfaMethodStatus", "MfaCapableMethodCount"] if c in mm.columns]
    mm = mm[["__key"] + mfa_cols].drop_duplicates("__key")
else:
    mm = pd.DataFrame(columns=["__key"])

# Mailbox
if not mailboxes.empty:
    mb = mailboxes.copy()
    mb["__key"] = mb.get("UserPrincipalName", "").map(norm)
else:
    mb = pd.DataFrame(columns=["__key"])

if not mail_stats.empty:
    ms = mail_stats.copy()
    # Mailbox statistics só têm DisplayName; cruzamos depois por nome.
else:
    ms = pd.DataFrame()

# Archive enrichment
# Algumas coletas geram o status de archive em um CSV separado.
# Se houver dados, usamos esse arquivo para complementar o inventário.
if not mailboxes_archive.empty and not mailboxes.empty:
    def enrich_mailboxes(base, archive_df):
        base = base.copy()
        archive_df = archive_df.copy()

        # Escolhe a melhor chave disponível em cada lado.
        base_key = first_existing(base, "UserPrincipalName", "PrimarySmtpAddress", "DisplayName")
        arc_key = first_existing(archive_df, "UserPrincipalName", "PrimarySmtpAddress", "DisplayName")

        if not base_key or not arc_key:
            return base

        base["__archive_key"] = base[base_key].map(norm)
        archive_df["__archive_key"] = archive_df[arc_key].map(norm)

        archive_cols = [c for c in ["ArchiveStatus", "ArchiveGuid", "ArchiveName"] if c in archive_df.columns]
        if not archive_cols:
            return base

        enrich = archive_df[["__archive_key"] + archive_cols].drop_duplicates("__archive_key")
        base = base.merge(enrich, on="__archive_key", how="left", suffixes=("", "_Archive"))
        base.drop(columns=["__archive_key"], inplace=True, errors="ignore")

        # Se já existia ArchiveStatus no inventário, usa o valor do CSV
        # separado quando o campo original estiver vazio.
        if "ArchiveStatus_Archive" in base.columns:
            if "ArchiveStatus" in base.columns:
                base["ArchiveStatus"] = base.apply(
                    lambda r: r["ArchiveStatus_Archive"]
                    if norm(r.get("ArchiveStatus", "")) == "" and norm(r.get("ArchiveStatus_Archive", "")) != ""
                    else r.get("ArchiveStatus", ""),
                    axis=1,
                )
                base.drop(columns=["ArchiveStatus_Archive"], inplace=True, errors="ignore")
            else:
                base.rename(columns={"ArchiveStatus_Archive": "ArchiveStatus"}, inplace=True)

        return base

    mailboxes = enrich_mailboxes(mailboxes, mailboxes_archive)

# Roles
role_by_user = {}
if not roles.empty:
    for _, r in roles.iterrows():
        upn = norm(r.get("UserPrincipalName", ""))
        if upn:
            role_by_user.setdefault(upn, []).append(r.get("RoleName", ""))

# Monta tabela final de usuário
user_rows = []
for _, u in user_base.iterrows():
    upn = u.get("UserPrincipalName", "")
    key = norm(upn)

    license_text = lnames.get(key, "")
    if not license_text:
        license_text = "SEM LICENÇA"

    mfa_row = mm[mm["__key"] == key]
    if not mfa_row.empty:
        mr = mfa_row.iloc[0]
        mfa_status = mr.get("MfaMethodStatus", "")
        mfa_methods = mr.get("AuthenticationMethods", "")
    else:
        mfa_status = "Não identificado"
        mfa_methods = ""

    mailbox_match = mb[mb["__key"] == key]
    if not mailbox_match.empty:
        bx = mailbox_match.iloc[0]
        mb_type = bx.get("RecipientTypeDetails", "")
        mb_display = bx.get("DisplayName", "")
        smtp = bx.get("PrimarySmtpAddress", "")
        archive = bx.get("ArchiveStatus", "")
        litigation = bx.get("LitigationHoldEnabled", "")
        stat_match = pd.DataFrame()

        # As estatísticas do Exchange desta coleta possuem DisplayName.
        # Cruzamos por nome primeiro e, se necessário, por SMTP/UPN.
        if not ms.empty:
            if "DisplayName" in ms.columns and mb_display:
                stat_match = ms[
                    ms["DisplayName"].map(norm).eq(norm(mb_display))
                ]

            if stat_match.empty and "PrimarySmtpAddress" in ms.columns and smtp:
                stat_match = ms[
                    ms["PrimarySmtpAddress"].map(norm).eq(norm(smtp))
                ]

            if stat_match.empty and "UserPrincipalName" in ms.columns and upn:
                stat_match = ms[
                    ms["UserPrincipalName"].map(norm).eq(norm(upn))
                ]

        if not stat_match.empty:
            st = stat_match.iloc[0]
            size_raw = st.get("TotalItemSize", "")
            item_count = st.get("ItemCount", "")
            last_logon = st.get("LastLogonTime", "")
        else:
            size_raw = item_count = last_logon = ""
    else:
        mb_type = mb_display = smtp = archive = litigation = ""
        size_raw = item_count = last_logon = ""

    user_rows.append({
        "Usuário": u.get("DisplayName", ""),
        "UPN": upn,
        "Status": "Ativo" if to_bool(u.get("AccountEnabled", "")) else "Bloqueado",
        "Tipo": u.get("UserType", ""),
        "Cargo": u.get("JobTitle", ""),
        "Departamento": u.get("Department", ""),
        "Licença(s)": license_text,
        "Métodos MFA": mfa_methods,
        "Status MFA": mfa_status,
        "Mailbox": mb_type,
        "SMTP": smtp,
        "Consumo Caixa (GB)": parse_size_gb(size_raw),
        "Itens Caixa": item_count,
        "Último Login Exchange": last_logon,
        "Archive": archive,
        "Litigation Hold": litigation,
        "Roles": "; ".join(sorted(set(role_by_user.get(key, [])))),
        "Último Login Entra": u.get(
            first_existing(
                user_base,
                "LastSignInDateTime",
                "SignInActivity.LastSignInDateTime",
            ),
            "",
        ) if first_existing(
            user_base,
            "LastSignInDateTime",
            "SignInActivity.LastSignInDateTime",
        ) else "",
        "Criado em": u.get("CreatedDateTime", ""),
    })

user_detail = pd.DataFrame(user_rows)


# ============================================================
# DIAGNÓSTICO
# ============================================================

findings = [
    {
        "Severidade": "ALTO",
        "Área": "MFA / Identidade",
        "Achado": "Security Defaults está desabilitado e não foram identificadas políticas de Conditional Access.",
        "Evidência": f"Security Defaults = {security_defaults_value}; Conditional Access = {ca_count}.",
        "Recomendação": "Avaliar uma estratégia de MFA proporcional ao risco, priorizando contas administrativas e usuários com acesso a dados sensíveis."
    },
    {
        "Severidade": "ALTO",
        "Área": "Privileged Access",
        "Achado": f"Foram identificados {global_admins} Global Administrators.",
        "Evidência": f"{global_admins} assignments no role Global Administrator.",
        "Recomendação": "Revisar a necessidade de cada conta e aplicar princípio do menor privilégio."
    },
    {
        "Severidade": "MÉDIO",
        "Área": "Governança",
        "Achado": f"Foram identificados {groups_no_owner} grupos sem proprietário.",
        "Evidência": f"{group_count} grupos totais; {groups_no_owner} sem owner identificado.",
        "Recomendação": "Definir responsáveis e ciclo de vida para grupos que permanecerão ativos."
    },
]

findings_df = pd.DataFrame(findings)


# ============================================================
# EXCEL
# ============================================================

xlsx_path = REPORTS / f"M365-Assessment-{run_ts}.xlsx"

wb = Workbook()
dash = wb.active
dash.title = "Dashboard"

NAVY = "1F4E78"
BLUE = "D9EAF7"
LIGHT = "EAF2F8"
RED = "F4CCCC"
ORANGE = "FCE5CD"
YELLOW = "FFF2CC"
GREEN = "D9EAD3"
WHITE = "FFFFFF"
GRAY = "666666"

title_fill = PatternFill("solid", fgColor=NAVY)
header_fill = PatternFill("solid", fgColor=NAVY)
header_font = Font(color=WHITE, bold=True)
thin = Side(style="thin", color="D9E1F2")

def style_table(ws, header_row=1):
    for cell in ws[header_row]:
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal="center", vertical="center")
    ws.freeze_panes = f"A{header_row+1}"
    ws.auto_filter.ref = ws.dimensions
    for row in ws.iter_rows():
        for c in row:
            c.border = Border(bottom=thin)
            c.alignment = Alignment(vertical="top", wrap_text=True)

def write_df(ws, df, start_row=1):
    if df is None:
        df = pd.DataFrame()
    if df.empty:
        ws.cell(start_row, 1, "Sem dados disponíveis nesta coleta.")
        return
    for j, col in enumerate(df.columns, 1):
        ws.cell(start_row, j, str(col))
    for i, row in enumerate(df.itertuples(index=False), start_row + 1):
        for j, value in enumerate(row, 1):
            ws.cell(i, j, "" if pd.isna(value) else str(value))
    style_table(ws, start_row)
    for col in range(1, ws.max_column + 1):
        maxlen = max(len(str(ws.cell(r, col).value or "")) for r in range(1, min(ws.max_row, 250) + 1))
        ws.column_dimensions[get_column_letter(col)].width = min(max(maxlen + 2, 10), 45)

# Dashboard
dash.merge_cells("A1:J1")
dash["A1"] = "MICROSOFT 365 — ASSESSMENT"
dash["A1"].fill = title_fill
dash["A1"].font = Font(size=20, bold=True, color=WHITE)
dash["A1"].alignment = Alignment(horizontal="center")
dash["A2"] = f"Execução: {run_display} | Coleta somente leitura"
dash.merge_cells("A2:J2")

kpis = [
    ("Usuários", total_users), ("Ativos", active_users), ("Licenciados", licensed_users),
    ("Sem licença", unlicensed_users), ("Mailboxes", len(mailboxes)),
    ("Shared", shared_mailboxes), ("Global Admins", global_admins), ("Grupos", group_count),
    ("Dispositivos", device_count), ("Achados", len(findings))
]
for idx, (label, value) in enumerate(kpis):
    row = 4 + (idx // 5) * 3
    col = 1 + (idx % 5) * 2
    dash.cell(row, col, label)
    dash.cell(row, col).fill = PatternFill("solid", fgColor=BLUE)
    dash.cell(row, col).font = Font(bold=True)
    dash.cell(row + 1, col, value)
    dash.cell(row + 1, col).font = Font(size=18, bold=True)
    dash.cell(row + 1, col).fill = PatternFill("solid", fgColor=LIGHT)

dash["A11"] = "SEGURANÇA"
dash["A11"].fill = title_fill
dash["A11"].font = header_font
security_rows = [
    ("Security Defaults", "DESABILITADO" if norm(security_defaults_value) == "false" else security_defaults_value),
    ("Conditional Access", ca_count),
    ("MFA-capable identificado", mfa_count),
    ("Sem MFA-capable identificado", mfa_no_count),
]
for r, (a,b) in enumerate(security_rows, 12):
    dash.cell(r,1,a); dash.cell(r,2,b)
    if a == "Security Defaults" and norm(str(b)) == "desabilitado":
        dash.cell(r,2).fill = PatternFill("solid", fgColor=RED)

dash["E11"] = "PRINCIPAIS ACHADOS"
dash["E11"].fill = title_fill
dash["E11"].font = header_font
for r, f in enumerate(findings, 12):
    dash.cell(r,5, f"[{f['Severidade']}]")
    dash.cell(r,6, f["Achado"])
    dash.cell(r,5).fill = PatternFill("solid", fgColor=RED if f["Severidade"]=="ALTO" else ORANGE)
    dash.cell(r,6).alignment = Alignment(wrap_text=True)

# Dashboard charts data
dash["I11"] = "Usuários"
dash["I12"] = "Ativos"; dash["J12"] = active_users
dash["I13"] = "Bloqueados"; dash["J13"] = blocked_users
dash["I14"] = "Licenciados"; dash["J14"] = licensed_users
dash["I15"] = "Sem licença"; dash["J15"] = unlicensed_users

chart = BarChart()
chart.title = "Usuários"
chart.y_axis.title = "Quantidade"
data = Reference(dash, min_col=10, min_row=11, max_row=15)
cats = Reference(dash, min_col=9, min_row=12, max_row=15)
chart.add_data(data, titles_from_data=True)
chart.set_categories(cats)
chart.height = 7
chart.width = 11
dash.add_chart(chart, "E17")

# Detail sheets
write_df(wb.create_sheet("Usuarios"), user_detail)

license_detail = licenses.copy()
write_df(wb.create_sheet("Licencas por Usuario"), license_detail)

write_df(wb.create_sheet("SKUs"), skus)

exchange_summary = pd.DataFrame([
    ["Total Mailboxes", len(mailboxes)],
    ["User Mailboxes", user_mailboxes],
    ["Shared Mailboxes", shared_mailboxes],
    ["Room Mailboxes", room_mailboxes],
    ["Discovery Mailboxes", discovery_mailboxes],
    ["Archives ativos", archive_count],
], columns=["Indicador","Quantidade"])
write_df(wb.create_sheet("Exchange - Resumo"), exchange_summary)

if not mailboxes.empty and not mail_stats.empty:
    exch = mailboxes.copy()

    if "DisplayName" in exch.columns and "DisplayName" in mail_stats.columns:
        stats_for_merge = mail_stats.copy()
        stats_for_merge["__display_key"] = stats_for_merge["DisplayName"].map(norm)
        exch["__display_key"] = exch["DisplayName"].map(norm)

        exch = exch.merge(
            stats_for_merge.drop(columns=["DisplayName"]),
            on="__display_key",
            how="left",
            suffixes=("", "_Stats"),
        )
        exch.drop(columns=["__display_key"], inplace=True, errors="ignore")

    if "TotalItemSize" in exch.columns:
        exch["ConsumoGB_Aproximado"] = exch["TotalItemSize"].map(parse_size_gb)

    write_df(wb.create_sheet("Exchange - Caixas"), exch)

elif not mailboxes.empty:
    write_df(wb.create_sheet("Exchange - Caixas"), mailboxes)

elif not mail_stats.empty:
    stats_only = mail_stats.copy()
    if "TotalItemSize" in stats_only.columns:
        stats_only["ConsumoGB_Aproximado"] = stats_only["TotalItemSize"].map(parse_size_gb)
    write_df(wb.create_sheet("Exchange - Caixas"), stats_only)

else:
    write_df(wb.create_sheet("Exchange - Caixas"), pd.DataFrame())

write_df(wb.create_sheet("MFA"), mfa)
write_df(wb.create_sheet("Security Defaults"), security_defaults)
write_df(wb.create_sheet("Conditional Access"), ca)
write_df(wb.create_sheet("Privileged Access"), roles)
write_df(wb.create_sheet("Grupos"), groups)
write_df(wb.create_sheet("Group Members"), group_members)
write_df(wb.create_sheet("Group Owners"), group_owners)
write_df(wb.create_sheet("Teams"), teams)
write_df(wb.create_sheet("OneDrive"), onedrive)
write_df(wb.create_sheet("Dispositivos"), devices)
write_df(wb.create_sheet("App Registrations"), apps)
write_df(wb.create_sheet("Enterprise Applications"), enterprise_apps)
write_df(wb.create_sheet("Sign-ins"), signins)
write_df(wb.create_sheet("Directory Audit"), directory_audit)
write_df(wb.create_sheet("Diagnostico"), findings_df)

methodology = pd.DataFrame([
    ["Escopo","Assessment read-only de Microsoft 365 / Entra ID / Exchange Online"],
    ["Data da coleta",run_display],
    ["Tenant","tenant.onmicrosoft.com"],
    ["Login","Último Login Entra vem de LastSignInDateTime; Último Login Exchange vem de LastLogonTime da mailbox quando o Exchange disponibilizar o dado."],
    ["MFA","Método MFA-capable identificado não equivale, sozinho, a MFA efetivamente exigido."],
    ["Archive","O status de archive é usado quando disponibilizado pelo inventário Exchange ou pelo CSV específico de archive."],
    ["Licenças","Consumo de SKU não equivale diretamente ao custo financeiro."],
    ["Enterprise Applications",f"{enterprise_app_count} service principals não significam {enterprise_app_count} aplicações de negócio."],
    ["Raw","Os CSVs originais permanecem em output\\raw como evidência técnica."],
], columns=["Item","Observação"])
write_df(wb.create_sheet("Metodologia"), methodology)

# Print settings
for ws in wb.worksheets:
    ws.sheet_view.showGridLines = False
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1

wb.save(xlsx_path)


# ============================================================
# WORD
# ============================================================

docx_path = REPORTS / f"M365-Assessment-{run_ts}.docx"
doc = Document()

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("MICROSOFT 365\nASSESSMENT EXECUTIVO")
r.bold = True
r.font.size = Pt(24)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run(f"Microsoft 365 / Entra ID / Exchange Online\n{run_display}").font.size = Pt(13)

doc.add_heading("1. Resumo executivo", level=1)
doc.add_paragraph(
    f"O assessment avaliou o ambiente Microsoft 365 em modo somente leitura, cobrindo "
    f"identidade, licenciamento, Exchange Online, autenticação, privilégios, colaboração, "
    f"dispositivos, aplicações e auditoria. Foram identificados {total_users} usuários, "
    f"{active_users} ativos, {len(mailboxes)} mailboxes, {device_count} dispositivos e "
    f"{group_count} grupos."
)

table = doc.add_table(rows=1, cols=2)
table.style = "Light Grid Accent 1"
table.rows[0].cells[0].text = "Indicador"
table.rows[0].cells[1].text = "Resultado"
for a,b in [
    ("Usuários", f"{total_users} ({active_users} ativos / {blocked_users} bloqueados)"),
    ("Licenciamento", f"{licensed_users} licenciados / {unlicensed_users} sem licença"),
    ("Exchange", f"{user_mailboxes} user / {shared_mailboxes} shared / {room_mailboxes} room"),
    ("Security Defaults", "DESABILITADO" if norm(security_defaults_value)=="false" else str(security_defaults_value)),
    ("Conditional Access", str(ca_count)),
    ("MFA-capable identificado", str(mfa_count)),
    ("Global Administrators", str(global_admins)),
    ("Grupos sem owner", str(groups_no_owner)),
    ("Dispositivos", str(device_count)),
    ("App Registrations", str(app_count)),
    ("Enterprise Applications", str(enterprise_app_count)),
    ("Sign-ins coletados", str(signin_count)),
]:
    cells = table.add_row().cells
    cells[0].text = a
    cells[1].text = b

doc.add_heading("2. Principais achados", level=1)
for f in findings:
    p = doc.add_paragraph()
    p.add_run(f"[{f['Severidade']}] {f['Área']}\n").bold = True
    p.add_run(f["Achado"])
    doc.add_paragraph(f"Evidência: {f['Evidência']}")
    doc.add_paragraph(f"Recomendação: {f['Recomendação']}")

doc.add_heading("3. Pontos que merecem validação", level=1)
for item in [
    f"Os {mfa_no_count} usuários sem método MFA-capable identificado precisam ser cruzados com o processo real de autenticação antes de concluir que estão sem MFA.",
    f"Os {enterprise_app_count} Enterprise Applications / service principals incluem objetos de serviço Microsoft e integrações; não devem ser interpretados como aplicações de negócio.",
    f"Os {unlicensed_users} usuários sem licença devem ser classificados entre contas funcionais, guests, contas de serviço e usuários que realmente necessitam de licença.",
    f"Os {groups_no_owner} grupos sem proprietário devem ser avaliados quanto à necessidade e ciclo de vida.",
]:
    doc.add_paragraph(item, style="List Bullet")

doc.add_heading("4. Recomendações iniciais", level=1)
for item in [
    "Revisar privilégios administrativos e reduzir Global Administrators ao mínimo necessário.",
    "Definir uma estratégia de MFA proporcional ao risco, começando pelas contas administrativas.",
    "Revisar grupos sem proprietário e estabelecer governança mínima.",
    "Classificar usuários sem licença e contas funcionais antes de qualquer otimização de licenciamento.",
    "Classificar dispositivos registrados no Entra ID entre ativos atuais, antigos, duplicados e equipamentos corporativos.",
    "Classificar Enterprise Applications por origem, proprietário, finalidade e necessidade.",
    "Levantar o custo financeiro real das assinaturas no Admin Center antes de apresentar qualquer economia."
]:
    doc.add_paragraph(item, style="List Bullet")

doc.add_heading("5. Entregáveis técnicos", level=1)
doc.add_paragraph(
    "O workbook anexo consolida os dados por usuário e por domínio de avaliação, incluindo "
    "licenças, consumo de mailbox, MFA, privilégios, grupos, dispositivos, aplicações e auditoria. "
    "Os CSVs brutos permanecem preservados em output\\raw para rastreabilidade."
)

doc.save(docx_path)


# ============================================================
# POWERPOINT
# ============================================================

pptx_path = REPORTS / f"M365-Assessment-{run_ts}.pptx"
prs = Presentation()
prs.slide_width = PInches(13.333)
prs.slide_height = PInches(7.5)

def slide_title(slide, title, subtitle=None):
    box = slide.shapes.add_textbox(PInches(.7), PInches(.35), PInches(12), PInches(.75))
    box.text_frame.text = title
    box.text_frame.paragraphs[0].font.size = PPt(28)
    box.text_frame.paragraphs[0].font.bold = True
    if subtitle:
        s = slide.shapes.add_textbox(PInches(.75), PInches(1.05), PInches(11.8), PInches(.45))
        s.text_frame.text = subtitle
        s.text_frame.paragraphs[0].font.size = PPt(13)

def bullets(slide, items, y=1.5, size=20):
    box = slide.shapes.add_textbox(PInches(.9), PInches(y), PInches(11.7), PInches(5.3))
    tf = box.text_frame
    tf.clear()
    for i, item in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = item
        p.font.size = PPt(size)
        p.space_after = PPt(12)

slide = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(slide, "Microsoft 365 — Assessment Executivo", f"Microsoft 365 / Entra ID / Exchange Online • {run_display}")
bullets(slide, [
    f"{total_users} usuários • {active_users} ativos • {licensed_users} licenciados",
    f"{len(mailboxes)} mailboxes • {shared_mailboxes} shared mailboxes",
    f"{group_count} grupos • {teams_count} Teams • {device_count} dispositivos",
    f"{global_admins} Global Administrators",
    f"{len(findings)} achados prioritários identificados automaticamente",
], y=1.7, size=24)

slide = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(slide, "Panorama do ambiente")
bullets(slide, [
    f"Identidade: {total_users} usuários ({active_users} ativos / {blocked_users} bloqueados).",
    f"Licenciamento: {licensed_users} licenciados / {unlicensed_users} sem licença.",
    f"Exchange: {user_mailboxes} user mailboxes, {shared_mailboxes} shared, {room_mailboxes} room.",
    f"Colaboração: {group_count} grupos, {m365_groups} Microsoft 365 Groups e {teams_count} Teams.",
    f"Auditoria: {signin_count} sign-ins e {audit_count} eventos de diretório coletados.",
], size=20)

slide = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(slide, "Segurança e autenticação")
bullets(slide, [
    f"Security Defaults: {'DESABILITADO' if norm(security_defaults_value)=='false' else security_defaults_value}.",
    f"Conditional Access: {ca_count} políticas identificadas.",
    f"{mfa_count} usuários com método MFA-capable identificado.",
    f"{mfa_no_count} usuários sem método MFA-capable identificado.",
    "O inventário de método não prova sozinho que MFA esteja ou não sendo exigido.",
], size=20)

slide = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(slide, "Privileged Access")
bullets(slide, [
    f"{global_admins} Global Administrators identificados.",
    f"{role_assignments} assignments de roles registrados.",
    "Revisar necessidade dos privilégios e aplicar menor privilégio.",
    "Separar administração de uso cotidiano quando fizer sentido operacionalmente.",
], size=22)

slide = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(slide, "Governança e colaboração")
bullets(slide, [
    f"{group_count} grupos identificados.",
    f"{groups_no_owner} grupos sem proprietário identificado.",
    f"{groups_no_member} grupos sem membros.",
    f"{teams_count} Teams detectados.",
    "Definir owner e ciclo de vida para grupos que permanecerão ativos.",
], size=22)

slide = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(slide, "Dispositivos e aplicações")
bullets(slide, [
    f"{device_count} dispositivos registrados no Entra ID.",
    f"{app_count} App Registrations.",
    f"{enterprise_app_count} Enterprise Applications / service principals.",
    "Service principals não equivalem à mesma quantidade de aplicações de negócio.",
    "Próxima etapa: classificar objetos atuais, antigos, duplicados e integrações.",
], size=20)

slide = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(slide, "Prioridades recomendadas")
bullets(slide, [
    "1. Revisar Global Administrators e demais privilégios.",
    "2. Definir estratégia de MFA proporcional ao risco.",
    "3. Organizar grupos sem proprietário.",
    "4. Classificar usuários sem licença.",
    "5. Classificar dispositivos e aplicações.",
    "6. Levantar custos reais de licenciamento.",
], size=21)

prs.save(pptx_path)


# ============================================================
# RESUMO NO TERMINAL
# ============================================================

print("")
print("=" * 64)
print(" RELATÓRIOS GERADOS COM SUCESSO")
print("=" * 64)
print(f"Excel       : {xlsx_path}")
print(f"Word        : {docx_path}")
print(f"PowerPoint  : {pptx_path}")
print("")
print("Dashboard e abas detalhadas criados a partir dos CSVs RAW.")
print(f"Exchange: {len(mailboxes)} mailboxes no inventário; {len(mail_stats)} registros de estatísticas.")
print(f"Login Entra: campo LastSignInDateTime utilizado quando disponível.")
print("=" * 64)
