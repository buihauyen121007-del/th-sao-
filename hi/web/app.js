let currentRunData = null;
let selectedApplicantId = null;
let pendingUploadFiles = {};
let chartMode = "applicants"; // "applicants" | "regions"

function escapeHtml(val) {
  if (val === null || val === undefined) return "";
  return String(val)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function recBadgeClass(code) {
  if (code === "CONTINUE") return "badge badge-ok";
  if (code === "SUPPLEMENT") return "badge badge-warn";
  return "badge badge-err";
}

function prioBadgeClass(code) {
  if (code === "P1" || code === "P2") return "badge badge-ok";
  if (code === "HOLD") return "badge badge-hold";
  if (code === "P3") return "badge badge-warn";
  return "badge badge-err";
}

function statusToneClass(app) {
  const d = app.decision || {};
  if (d.requires_human_escalation) return "st-hold";
  if (d.recommendation_code === "CONTINUE") return "st-ok";
  if (d.recommendation_code === "SUPPLEMENT") return "st-warn";
  return "st-err";
}

function getInitials(name, fallbackId) {
  const txt = (name || fallbackId || "DT").trim();
  const words = txt.split(/\s+/).filter(Boolean);
  if (words.length >= 2) {
    return (words[0][0] + words[words.length - 1][0]).toUpperCase();
  }
  return txt.slice(0, 2).toUpperCase();
}

async function apiGet(url) {
  const res = await fetch(url);
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "API error");
  return data;
}

async function apiPost(url, payload) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "API error");
  return data;
}

function switchTab(tabId) {
  let matchedTitle = null;
  document.querySelectorAll(".tab-btn").forEach((b) => {
    const isMatch = b.dataset.tab === tabId;
    b.classList.toggle("active", isMatch);
    if (isMatch && b.dataset.title && !matchedTitle) {
      matchedTitle = b.dataset.title;
    }
  });
  document.querySelectorAll(".tab-panel").forEach((p) => {
    p.classList.toggle("active", p.id === tabId);
  });
  const titleEl = document.getElementById("pageMainTitle");
  if (titleEl && matchedTitle) {
    titleEl.textContent = matchedTitle;
  }
}

document.querySelectorAll(".tab-btn").forEach((btn) => {
  btn.addEventListener("click", () => switchTab(btn.dataset.tab));
});

function refreshDatasetDropdowns(datasets, preferredName) {
  const dsSelect = document.getElementById("datasetSelect");
  const prev = preferredName || (dsSelect ? dsSelect.value : "");
  if (dsSelect) {
    dsSelect.innerHTML = "";
    (datasets || []).forEach((d) => {
      const opt = document.createElement("option");
      opt.value = d.name;
      opt.textContent = d.name;
      dsSelect.appendChild(opt);
    });
    if (prev && Array.from(dsSelect.options).some((o) => o.value === prev)) {
      dsSelect.value = prev;
    }
  }
  const baseSel = document.getElementById("createBaseDataset");
  if (baseSel) {
    const prevBase = baseSel.value || "sample_exam_pack";
    baseSel.innerHTML = "";
    (datasets || []).forEach((d) => {
      const opt = document.createElement("option");
      opt.value = d.name;
      opt.textContent = d.name;
      baseSel.appendChild(opt);
    });
    if (Array.from(baseSel.options).some((o) => o.value === prevBase)) {
      baseSel.value = prevBase;
    }
  }
}

async function initApp() {
  const pill = document.getElementById("serverStatusPill");
  try {
    const [healthData, dsData, cfgData, runsData] = await Promise.all([
      apiGet("/api/health"),
      apiGet("/api/datasets"),
      apiGet("/api/config"),
      apiGet("/api/runs")
    ]);
    if (pill && healthData.status === "ok") {
      pill.className = "badge badge-ok";
      pill.textContent = `Localhost Online (${healthData.url || window.location.origin})`;
    }

    refreshDatasetDropdowns(dsData.datasets || []);

    document.getElementById("rulesEditor").value = JSON.stringify(cfgData.rules, null, 2);
    document.getElementById("schemaEditor").value = JSON.stringify(cfgData.schema, null, 2);

    refreshPastRunsSelect(runsData.runs || []);
    if (runsData.runs && runsData.runs.length > 0) {
      await loadSavedRun(runsData.runs[0].run_id);
    } else {
      renderEmptyOverview();
    }
    if (typeof loadTargetDatasetDossiers === "function") {
      await loadTargetDatasetDossiers();
    }
  } catch (err) {
    console.error("Init error:", err);
    if (pill) {
      pill.className = "badge badge-err";
      pill.textContent = "Mất kết nối server localhost";
    }
    renderEmptyOverview();
  }
}

function renderEmptyOverview() {
  const partnerList = document.getElementById("overviewPartnerList");
  if (partnerList) {
    partnerList.innerHTML = '<div class="empty-card-hint">Chưa có dữ liệu. Nhấn <strong>Chạy AI Agent</strong> để nạp &amp; đánh giá hồ sơ.</div>';
  }
  const svg = document.getElementById("heroAreaChart");
  if (svg) svg.innerHTML = "";
}

function refreshPastRunsSelect(runs) {
  const sel = document.getElementById("pastRunsSelect");
  sel.innerHTML = '<option value="">-- Tải phiên chạy đã lưu --</option>';
  runs.forEach((r) => {
    const opt = document.createElement("option");
    opt.value = r.run_id;
    opt.textContent = r.run_id;
    sel.appendChild(opt);
  });
}

async function loadSavedRun(runId) {
  if (!runId) return;
  try {
    const data = await apiGet("/api/runs/" + encodeURIComponent(runId));
    renderRunResult(data);
  } catch (err) {
    alert("Không tải được phiên chạy: " + err.message);
  }
}

async function executeAgentRun() {
  const btn = document.getElementById("runAgentBtn");
  const heroBtn = document.getElementById("heroRunBtn");
  [btn, heroBtn].forEach((b) => {
    if (b) {
      b.disabled = true;
      b.textContent = "Đang chạy Agent...";
    }
  });
  try {
    const payload = {
      dataset_name: document.getElementById("datasetSelect").value,
      mode: document.getElementById("modeSelect").value,
      llm_provider: document.getElementById("providerSelect").value,
      model_name: document.getElementById("modelNameInput").value.trim(),
      api_key: document.getElementById("apiKeyInput").value.trim()
    };
    const data = await apiPost("/api/run", payload);
    renderRunResult(data);
    const runsData = await apiGet("/api/runs");
    refreshPastRunsSelect(runsData.runs || []);
  } catch (err) {
    alert("Lỗi khi chạy AI Agent: " + err.message);
  } finally {
    [btn, heroBtn].forEach((b) => {
      if (b) {
        b.disabled = false;
        b.textContent = "Chạy AI Agent";
      }
    });
  }
}

function renderRunResult(data) {
  currentRunData = data;
  const s = data.summary || {};
  const applicants = data.applicants || [];

  if (!selectedApplicantId || !applicants.some((a) => a.profile.applicant_id === selectedApplicantId)) {
    selectedApplicantId = applicants.length ? applicants[0].profile.applicant_id : null;
  }

  document.getElementById("kpiTotal").textContent = s.total_applicants ?? 0;
  document.getElementById("kpiContinue").textContent = s.continue_count ?? 0;
  document.getElementById("kpiSupplement").textContent = s.supplement_count ?? 0;
  document.getElementById("kpiNotContinue").textContent = s.not_continue_count ?? 0;
  document.getElementById("kpiEscalations").textContent = s.escalation_count ?? 0;
  document.getElementById("kpiLogs").textContent = data.audit_log_count ?? (data.audit_logs ? data.audit_logs.length : 0);

  const banner = document.getElementById("runBanner").querySelector("span");
  banner.innerHTML = `Phiên: <strong>${escapeHtml(data.run_id)}</strong> | Chế độ: <code>${escapeHtml(data.execution_mode)}</code> | Nguồn: <code>${escapeHtml(data.data_dir)}</code>`;
  document.getElementById("downloadJsonBtn").disabled = false;

  renderOverviewWorkspace();
  renderRegionalSummary(s.regional_summary || []);
  renderDossiersTab(applicants);
  renderEscalationsTab(s.escalation_register || []);
  renderVerificationPlan(s.verification_plan || []);
  renderLogsTab(data.audit_logs || [], applicants);
  updateFlowchartLiveStats(data);
}

/* ==================== OVERVIEW BENTO WORKSPACE ==================== */
function renderOverviewWorkspace() {
  if (!currentRunData) {
    renderEmptyOverview();
    return;
  }
  const applicants = currentRunData.applicants || [];
  const searchEl = document.getElementById("overviewSearchInput");
  const query = (searchEl ? searchEl.value : "").trim().toLowerCase();

  const filtered = applicants.filter((a) => {
    if (!query) return true;
    const p = a.profile || {};
    const hay = `${p.applicant_id} ${p.partner_name} ${p.region} ${p.province} ${p.district}`.toLowerCase();
    return hay.includes(query);
  });

  renderOverviewPartnerList(filtered);
  renderHeroCard(applicants);
  renderOverviewFeed(filtered);
  renderOverviewDetailPanel(applicants);
}

function renderOverviewPartnerList(list) {
  const el = document.getElementById("overviewPartnerList");
  if (!el) return;
  if (!list.length) {
    el.innerHTML = '<div class="empty-card-hint">Không tìm thấy đối tác khớp từ khóa.</div>';
    return;
  }

  el.innerHTML = list.map((a) => {
    const p = a.profile || {};
    const sc = a.scoring || {};
    const active = p.applicant_id === selectedApplicantId ? "active" : "";
    const initials = getInitials(p.partner_name, p.applicant_id);
    return `
      <div class="partner-card ${active}" onclick="selectOverviewApplicant('${escapeHtml(p.applicant_id)}')">
        <div class="partner-card-left">
          <div class="partner-avatar">${escapeHtml(initials)}</div>
          <div class="partner-meta">
            <div class="partner-name" title="${escapeHtml(p.partner_name)}">${escapeHtml(p.partner_name || p.applicant_id)}</div>
            <div class="partner-sub">${escapeHtml(p.applicant_id)} · Điểm: ${sc.verified_score ?? 0}/100 · ${escapeHtml(p.region || "")}</div>
          </div>
        </div>
        <svg class="partner-card-gear" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="3"></circle>
          <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9c.26.6.77 1 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
        </svg>
      </div>
    `;
  }).join("");
}

function renderHeroCard(applicants) {
  const active = applicants.find((a) => a.profile.applicant_id === selectedApplicantId) || applicants[0];
  const emblemEl = document.getElementById("heroEmblem");
  const metricEl = document.getElementById("heroMetricValue");
  const subEl = document.getElementById("heroMetricSub");
  const capEl = document.getElementById("heroChartCaption");

  if (!active) return;

  if (chartMode === "applicants") {
    const p = active.profile || {};
    const sc = active.scoring || {};
    const d = active.decision || {};
    if (emblemEl) emblemEl.textContent = p.applicant_id || "HS";
    if (metricEl) metricEl.textContent = `${sc.verified_score ?? 0} / 100 điểm`;
    if (subEl) subEl.textContent = `${d.recommendation_label || ""} · Tự khai ${sc.claimed_score ?? 0}đ`;
    if (capEl) capEl.textContent = "Điểm thực chứng vs Tự khai";
    renderApplicantsAreaChart(applicants);
  } else {
    const s = currentRunData.summary || {};
    const regions = s.regional_summary || [];
    if (emblemEl) emblemEl.textContent = `${s.continue_count ?? 0}/${s.total_applicants ?? 0}`;
    if (metricEl) metricEl.textContent = `${s.continue_count ?? 0} Đối tác Tiếp tục`;
    if (subEl) subEl.textContent = `Trong ${s.total_applicants ?? 0} hồ sơ · ${s.escalation_count ?? 0} chuyển cấp`;
    if (capEl) capEl.textContent = "Điểm trung bình theo 3 khu vực";
    renderRegionsAreaChart(regions);
  }
}

function renderApplicantsAreaChart(applicants) {
  const svg = document.getElementById("heroAreaChart");
  const tip = document.getElementById("chartTooltip");
  if (!svg || !applicants.length) return;

  const w = 560;
  const h = 125;
  const padX = 22;
  const padTop = 14;
  const padBot = 20;
  const plotW = w - padX * 2;
  const plotH = h - padTop - padBot;

  const n = applicants.length;
  const stepX = n > 1 ? plotW / (n - 1) : plotW;
  const labelStride = n > 12 ? Math.ceil(n / 10) : 1;

  const ptsV = applicants.map((a, idx) => {
    const x = padX + (n > 1 ? idx * stepX : plotW / 2);
    const val = Math.max(0, Math.min(100, Number(a.scoring?.verified_score ?? 0)));
    const y = padTop + plotH - (val / 100) * plotH;
    return { x, y, val, app: a };
  });

  const ptsC = applicants.map((a, idx) => {
    const x = padX + (n > 1 ? idx * stepX : plotW / 2);
    const val = Math.max(0, Math.min(100, Number(a.scoring?.claimed_score ?? 0)));
    const y = padTop + plotH - (val / 100) * plotH;
    return { x, y, val };
  });

  const lineV = ptsV.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const lineC = ptsC.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const areaV = `${lineV} L ${ptsV[ptsV.length - 1].x.toFixed(1)} ${(padTop + plotH).toFixed(1)} L ${ptsV[0].x.toFixed(1)} ${(padTop + plotH).toFixed(1)} Z`;

  svg.innerHTML = `
    <defs>
      <linearGradient id="pinkAreaGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#ffb8da" stop-opacity="0.52" />
        <stop offset="75%" stop-color="#ff69b4" stop-opacity="0.18" />
        <stop offset="100%" stop-color="#ffb8da" stop-opacity="0.0" />
      </linearGradient>
    </defs>
    <line x1="${padX}" y1="${padTop + plotH * 0.25}" x2="${w - padX}" y2="${padTop + plotH * 0.25}" stroke="rgba(255, 214, 234, 0.22)" stroke-dasharray="3 4" />
    <line x1="${padX}" y1="${padTop + plotH * 0.55}" x2="${w - padX}" y2="${padTop + plotH * 0.55}" stroke="rgba(255, 214, 234, 0.22)" stroke-dasharray="3 4" />
    <path d="${areaV}" fill="url(#pinkAreaGrad)" />
    <path d="${lineC}" fill="none" stroke="rgba(255, 214, 234, 0.52)" stroke-width="1.6" stroke-dasharray="5 4" />
    <path d="${lineV}" fill="none" stroke="#ffd0e6" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" />
    ${ptsV.map((pt, idx) => {
      const id = pt.app.profile.applicant_id;
      const isActive = id === selectedApplicantId;
      const baseR = n > 18 ? 2.6 : 3.5;
      const showLabel = isActive || (idx % labelStride === 0);
      return `
        <g class="chart-node" data-idx="${idx}" style="cursor:pointer;">
          <circle cx="${pt.x.toFixed(1)}" cy="${pt.y.toFixed(1)}" r="12" fill="transparent"></circle>
          <circle cx="${pt.x.toFixed(1)}" cy="${pt.y.toFixed(1)}" r="${isActive ? 5.5 : baseR}"
            fill="${isActive ? "#ffffff" : "#6e1843"}"
            stroke="#ffd0e6" stroke-width="${isActive ? 2.6 : 2}" />
          ${showLabel ? `<text x="${pt.x.toFixed(1)}" y="${h - 4}" text-anchor="middle" font-size="9.5" font-weight="${isActive ? 800 : 600}" fill="${isActive ? "#ffffff" : "#ffd6ea"}">${escapeHtml(id)}</text>` : ""}
        </g>
      `;
    }).join("")}
  `;

  svg.querySelectorAll(".chart-node").forEach((node) => {
    const idx = Number(node.getAttribute("data-idx"));
    const pt = ptsV[idx];
    node.addEventListener("mouseenter", () => {
      if (!tip) return;
      const p = pt.app.profile;
      tip.innerHTML = `<strong>${escapeHtml(p.applicant_id)}</strong> · ${escapeHtml(p.partner_name)}<br>Thực chứng: <strong>${pt.val}</strong> | Tự khai: ${pt.app.scoring?.claimed_score ?? 0}`;
      tip.classList.remove("hidden");
    });
    node.addEventListener("mouseleave", () => {
      if (tip) tip.classList.add("hidden");
    });
    node.addEventListener("click", () => {
      selectOverviewApplicant(pt.app.profile.applicant_id);
    });
  });
}

function renderRegionsAreaChart(regions) {
  const svg = document.getElementById("heroAreaChart");
  const tip = document.getElementById("chartTooltip");
  if (!svg || !regions.length) return;

  const w = 560;
  const h = 125;
  const padX = 56;
  const padTop = 18;
  const padBot = 22;
  const plotW = w - padX * 2;
  const plotH = h - padTop - padBot;

  const pts = regions.map((rg, idx) => {
    const x = regions.length > 1 ? padX + idx * (plotW / (regions.length - 1)) : w / 2;
    const partners = rg.partners || [];
    const avg = partners.length
      ? Math.round(partners.reduce((acc, p) => acc + Number(p.verified_score || 0), 0) / partners.length)
      : 0;
    const y = padTop + plotH - (avg / 100) * plotH;
    return { x, y, avg, rg };
  });

  const line = pts.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const area = `${line} L ${pts[pts.length - 1].x.toFixed(1)} ${(padTop + plotH).toFixed(1)} L ${pts[0].x.toFixed(1)} ${(padTop + plotH).toFixed(1)} Z`;

  svg.innerHTML = `
    <defs>
      <linearGradient id="pinkAreaGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#ffb8da" stop-opacity="0.52" />
        <stop offset="100%" stop-color="#ffb8da" stop-opacity="0.0" />
      </linearGradient>
    </defs>
    <path d="${area}" fill="url(#pinkAreaGrad)" />
    <path d="${line}" fill="none" stroke="#ffd0e6" stroke-width="3" stroke-linecap="round" />
    ${pts.map((p, i) => `
      <g class="reg-node" data-idx="${i}" style="cursor:pointer;">
        <circle cx="${p.x.toFixed(1)}" cy="${p.y.toFixed(1)}" r="6" fill="#6e1843" stroke="#ffd0e6" stroke-width="3" />
        <text x="${p.x.toFixed(1)}" y="${(p.y - 10).toFixed(1)}" text-anchor="middle" font-size="11" font-weight="800" fill="#ffffff">${p.avg}đ</text>
        <text x="${p.x.toFixed(1)}" y="${h - 5}" text-anchor="middle" font-size="10.5" font-weight="700" fill="#ffd6ea">${escapeHtml(p.rg.region)} (${p.rg.continue_count}/${p.rg.total})</text>
      </g>
    `).join("")}
  `;

  svg.querySelectorAll(".reg-node").forEach((node) => {
    const idx = Number(node.getAttribute("data-idx"));
    const p = pts[idx];
    node.addEventListener("mouseenter", () => {
      if (!tip) return;
      tip.innerHTML = `<strong>${escapeHtml(p.rg.region)}</strong> · TB: ${p.avg}đ<br>Tiếp tục: ${p.rg.continue_count} | Bổ sung: ${p.rg.supplement_count} | Chuyển cấp: ${p.rg.escalation_count}`;
      tip.classList.remove("hidden");
    });
    node.addEventListener("mouseleave", () => {
      if (tip) tip.classList.add("hidden");
    });
  });
}

function renderOverviewFeed(list) {
  const pendingEl = document.getElementById("overviewPendingList");
  const compEl = document.getElementById("overviewCompletedList");
  const pendingCnt = document.getElementById("overviewPendingCount");
  const compCnt = document.getElementById("overviewCompletedCount");
  if (!pendingEl || !compEl) return;

  const pendingItems = list.filter((a) => a.decision?.requires_human_escalation || a.decision?.recommendation_code === "SUPPLEMENT");
  const completedItems = list.filter((a) => !(a.decision?.requires_human_escalation || a.decision?.recommendation_code === "SUPPLEMENT"));

  if (pendingCnt) pendingCnt.textContent = pendingItems.length;
  if (compCnt) compCnt.textContent = completedItems.length;

  const drawRows = (arr) => {
    if (!arr.length) return '<div class="empty-card-hint">Không có hồ sơ trong nhóm này.</div>';
    return arr.map((a) => {
      const p = a.profile || {};
      const d = a.decision || {};
      const sc = a.scoring || {};
      const active = p.applicant_id === selectedApplicantId ? "active" : "";
      const tone = statusToneClass(a);
      const stText = d.requires_human_escalation
        ? `Chuyển thẩm quyền (${(d.escalations || []).map((e) => e.code).join(", ")})`
        : (d.recommendation_label || d.recommendation_code);

      return `
        <div class="feed-row ${active}" onclick="selectOverviewApplicant('${escapeHtml(p.applicant_id)}')">
          <div class="feed-row-left">
            <div class="feed-icon-box">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <line x1="12" y1="5" x2="12" y2="19"></line>
                <polyline points="19 12 12 19 5 12"></polyline>
              </svg>
            </div>
            <div style="min-width:0;">
              <div class="feed-title">${escapeHtml(p.applicant_id)} · ${escapeHtml(p.partner_name)}</div>
              <div class="feed-status ${tone}">${escapeHtml(stText)}</div>
            </div>
          </div>
          <div class="feed-row-right">
            <div class="feed-score">${sc.verified_score ?? 0} / 100</div>
            <div class="feed-subval">${escapeHtml(d.priority_code || "")} · Tự khai ${sc.claimed_score ?? 0}</div>
          </div>
        </div>
      `;
    }).join("");
  };

  pendingEl.innerHTML = drawRows(pendingItems);
  compEl.innerHTML = drawRows(completedItems);
}

function renderOverviewDetailPanel(applicants) {
  const panel = document.getElementById("overviewDetailPanel");
  if (!panel) return;
  const active = applicants.find((a) => a.profile.applicant_id === selectedApplicantId) || applicants[0];
  if (!active) {
    panel.innerHTML = '<p class="muted-text">Chưa có hồ sơ được chọn.</p>';
    return;
  }

  const p = active.profile || {};
  const d = active.decision || {};
  const sc = active.scoring || {};
  const v = p.verification || {};
  const issues = (d.failed_and_conflict_items || []).slice(0, 2);
  const missing = (d.unknown_or_missing_items || []).slice(0, 2);

  panel.innerHTML = `
    <div class="detail-kv">
      <span class="detail-k">Mã HS &amp; Mã số thuế</span>
      <span class="detail-v link-accent">${escapeHtml(p.applicant_id)} · MST: ${escapeHtml(p.tax_id || "Thiếu")}</span>
    </div>
    <div class="detail-kv">
      <span class="detail-k">Đề xuất AI &amp; Mức ưu tiên</span>
      <span class="detail-v">
        <span class="${recBadgeClass(d.recommendation_code)}">${escapeHtml(d.recommendation_label)}</span>
        <span class="${prioBadgeClass(d.priority_code)}">${escapeHtml(d.priority_code)}</span>
      </span>
    </div>
    <div class="detail-kv">
      <span class="detail-k">Khu vực &amp; Địa bàn</span>
      <span class="detail-v">${escapeHtml(p.region || "")} · ${escapeHtml(p.district || "")}, ${escapeHtml(p.province || "")}</span>
    </div>
    <div class="detail-kv">
      <span class="detail-k">Kế hoạch nhập &amp; Công nợ yêu cầu</span>
      <span class="detail-v">${p.monthly_purchase_vnd_million ?? "?"} tr/tháng · CN ${p.requested_credit_days ?? "?"} ngày (${p.requested_credit_limit_vnd_million ?? "?"} tr)</span>
    </div>
    <div class="detail-kv">
      <span class="detail-k">Điểm thực chứng / Điểm tự khai</span>
      <span class="detail-v" style="color:var(--pink-vivid);">${sc.verified_score ?? 0} / 100 (Tự khai: ${sc.claimed_score ?? 0})</span>
    </div>

    <div class="timeline-box">
      <div class="tl-step">
        <div class="tl-dot done"></div>
        <div class="tl-text"><strong>Kỹ năng 1 (Danh tính &amp; Địa bàn):</strong> ${escapeHtml(issues[0] || "Không xung đột hệ thống / địa bàn bảo hộ")}</div>
      </div>
      <div class="tl-step">
        <div class="tl-dot done"></div>
        <div class="tl-text"><strong>Kỹ năng 2 (Xác minh &amp; Chấm điểm):</strong> POS: ${escapeHtml(v.pos_verified || "?")}, BH: ${escapeHtml(v.warranty_verified || "?")}, TC: ${escapeHtml(v.financial_verified || "?")}</div>
      </div>
      <div class="tl-step">
        <div class="tl-dot ${d.requires_human_escalation || missing.length ? "pending" : "done"}"></div>
        <div class="tl-text">
          <strong>${d.requires_human_escalation ? "Chờ người có thẩm quyền:" : (missing.length ? "Chờ bổ sung:" : "Sẵn sàng trao đổi:")}</strong>
          ${escapeHtml(d.requires_human_escalation ? ((d.escalations || [])[0]?.escalate_to || "Trưởng phòng") : (missing[0] || "Đã tạo bản nháp email & phiếu xác minh."))}
        </div>
      </div>
    </div>

    <div class="details-footer-btns">
      <button type="button" class="btn btn-soft-pink btn-sm" onclick="copyOverviewDraft('${escapeHtml(p.applicant_id)}')">Copy bản nháp Email</button>
      <button type="button" class="btn btn-outline btn-sm" onclick="openApplicantDetail('${escapeHtml(p.applicant_id)}')">Xem chi tiết</button>
    </div>
  `;
}

window.selectOverviewApplicant = function(appId) {
  selectedApplicantId = appId;
  renderOverviewWorkspace();
  if (currentRunData) renderDossiersTab(currentRunData.applicants || []);
};

window.copyOverviewDraft = async function(appId) {
  if (!currentRunData) return;
  const app = (currentRunData.applicants || []).find((a) => a.profile.applicant_id === appId);
  if (!app || !app.draft) return;
  const fullText = `Tiêu đề: ${app.draft.subject}\n\n${app.draft.body}`;
  try {
    await navigator.clipboard.writeText(fullText);
    alert("Đã sao chép bản nháp trao đổi của hồ sơ " + appId + "!");
  } catch {
    openApplicantDetail(appId);
  }
};

/* ==================== STANDARD TABS 1 - 7 ==================== */
function renderRegionalSummary(regions) {
  const container = document.getElementById("regionalContainer");
  if (!regions.length) {
    container.innerHTML = '<div class="card">Không có dữ liệu khu vực.</div>';
    return;
  }
  container.innerHTML = regions.map((rg) => `
    <div class="card">
      <div class="card-header">
        <h3 class="card-title">Khu vực: ${escapeHtml(rg.region)} (${rg.total} hồ sơ)</h3>
        <div style="display:flex; gap:6px; flex-wrap:wrap;">
          <span class="badge badge-ok">Tiếp tục: ${rg.continue_count}</span>
          <span class="badge badge-warn">Bổ sung: ${rg.supplement_count}</span>
          <span class="badge badge-err">Chưa tiếp tục: ${rg.not_continue_count}</span>
          <span class="badge badge-hold">Chuyển thẩm quyền: ${rg.escalation_count}</span>
        </div>
      </div>
      <div style="overflow-x:auto;">
        <table>
          <thead>
            <tr>
              <th>Mã HS</th>
              <th>Đối tác</th>
              <th>Địa bàn</th>
              <th>Điểm thực chứng</th>
              <th>Điểm tự khai</th>
              <th>Mức ưu tiên</th>
              <th>Đề xuất</th>
              <th>Chuyển thẩm quyền</th>
              <th>Thao tác</th>
            </tr>
          </thead>
          <tbody>
            ${(rg.partners || []).map((p) => `
              <tr>
                <td><strong>${escapeHtml(p.applicant_id)}</strong></td>
                <td>
                  ${escapeHtml(p.partner_name)}
                  ${p.unverified_high_commitment ? '<br><span class="badge badge-warn">Cam kết cao chưa xác minh</span>' : ''}
                </td>
                <td>${escapeHtml(p.province_district)}</td>
                <td><strong>${p.verified_score}</strong> / 100</td>
                <td class="muted-text">${p.claimed_score} / 100</td>
                <td><span class="${prioBadgeClass(p.priority.split(' ')[0])}">${escapeHtml(p.priority)}</span></td>
                <td><span class="${recBadgeClass(p.recommendation_code)}">${escapeHtml(p.recommendation)}</span></td>
                <td>${p.requires_escalation ? (p.escalation_codes || []).map((c) => `<span class="badge badge-hold" style="margin:1px;">${escapeHtml(c)}</span>`).join(" ") : '<span class="badge badge-neutral">Không</span>'}</td>
                <td><button class="btn btn-soft-pink btn-sm" onclick="openApplicantDetail('${escapeHtml(p.applicant_id)}')">Xem hồ sơ</button></td>
              </tr>
            `).join("")}
          </tbody>
        </table>
      </div>
    </div>
  `).join("");
}

window.openApplicantDetail = function(appId) {
  selectedApplicantId = appId;
  switchTab("tab-dossiers");
  if (currentRunData) renderDossiersTab(currentRunData.applicants || []);
};

function renderDossiersTab(applicants) {
  const listEl = document.getElementById("dossierList");
  if (!applicants.length) {
    listEl.innerHTML = "<p>Không có hồ sơ.</p>";
    return;
  }
  if (!selectedApplicantId || !applicants.some((a) => a.profile.applicant_id === selectedApplicantId)) {
    selectedApplicantId = applicants[0].profile.applicant_id;
  }
  listEl.innerHTML = applicants.map((a) => {
    const p = a.profile;
    const d = a.decision;
    const sel = p.applicant_id === selectedApplicantId ? "selected" : "";
    return `
      <div class="dossier-item ${sel}" onclick="selectApplicant('${escapeHtml(p.applicant_id)}')">
        <div style="display:flex; justify-content:space-between; align-items:center; gap:6px;">
          <strong>${escapeHtml(p.applicant_id)} — ${escapeHtml(p.partner_name || "Chưa rõ tên")}</strong>
        </div>
        <div style="font-size:0.8rem; color:var(--text-muted); margin:4px 0;">${escapeHtml(p.region)} • Thực chứng: <strong>${a.scoring.verified_score}</strong> (Tự khai: ${a.scoring.claimed_score})</div>
        <div>
          <span class="${recBadgeClass(d.recommendation_code)}">${escapeHtml(d.recommendation_label)}</span>
          <span class="${prioBadgeClass(d.priority_code)}">${escapeHtml(d.priority_code)}</span>
        </div>
      </div>
    `;
  }).join("");

  const active = applicants.find((a) => a.profile.applicant_id === selectedApplicantId) || applicants[0];
  renderSingleDossierDetail(active);
}

window.selectApplicant = function(appId) {
  selectedApplicantId = appId;
  renderOverviewWorkspace();
  if (currentRunData) renderDossiersTab(currentRunData.applicants || []);
};

function renderSingleDossierDetail(app) {
  const p = app.profile;
  const d = app.decision;
  const sc = app.scoring;
  const g = app.gates;
  const v = p.verification || {};
  const detailEl = document.getElementById("dossierDetail");

  const escAlert = d.requires_human_escalation
    ? `<div class="alert-box alert-err"><strong>Chuyển người có thẩm quyền:</strong> ${(d.escalations || []).map((e) => `[${escapeHtml(e.code)}] ${escapeHtml(e.escalate_to)}: ${escapeHtml(e.detail)}`).join(" | ")}</div>`
    : "";

  const commitAlert = g.unverified_high_commitment_warning
    ? `<div class="alert-box alert-warn"><strong>Cảnh báo thiên lệch cam kết:</strong> ${escapeHtml(g.commitment_note)}</div>`
    : "";

  const aiSummaryBox = app.ai_reasoning
    ? `<div class="alert-box alert-info"><strong>Phân tích từ LLM Function Calling:</strong><br>${escapeHtml(app.ai_reasoning)}</div>`
    : "";

  detailEl.innerHTML = `
    <div class="card-header">
      <div>
        <h3 class="card-title" style="font-size:1.15rem;">${escapeHtml(p.applicant_id)} — ${escapeHtml(p.partner_name)}</h3>
        <div class="muted-text" style="font-size:0.84rem;">
          MST: <strong>${escapeHtml(p.tax_id || "Thiếu")}</strong> | Đại diện: ${escapeHtml(p.representative || "Thiếu")} | SĐT: ${escapeHtml(p.phone || "Thiếu")} | Khu vực: <strong>${escapeHtml(p.region)}</strong>
        </div>
        <div class="muted-text" style="font-size:0.84rem;">Điểm bán: ${escapeHtml(p.pos_address || "Thiếu")}</div>
      </div>
      <div style="text-align:right;">
        <span class="${recBadgeClass(d.recommendation_code)}" style="font-size:0.86rem;padding:4px 12px;">${escapeHtml(d.recommendation_label)}</span>
        <div style="margin-top:5px;"><span class="${prioBadgeClass(d.priority_code)}">${escapeHtml(d.priority_label)}</span></div>
      </div>
    </div>

    ${escAlert}
    ${commitAlert}
    ${aiSummaryBox}

    <div class="grid-2" style="margin-bottom:14px;">
      <div>
        <h4 style="margin:0 0 8px; color:var(--pink-vivid);">Chấm điểm tiêu chí (Thực chứng vs Tự khai)</h4>
        <table>
          <thead><tr><th>Tiêu chí</th><th>Trọng số</th><th>Tự khai</th><th>Thực chứng</th><th>Xác minh</th></tr></thead>
          <tbody>
            ${(sc.breakdown || []).map((b) => `
              <tr>
                <td>${escapeHtml(b.id)}</td>
                <td>${b.weight}</td>
                <td>${b.claimed}</td>
                <td><strong>${b.verified}</strong></td>
                <td><span class="badge ${b.evidence_status === 'VERIFIED_PASS' ? 'badge-ok' : (b.evidence_status === 'VERIFIED_FAIL' ? 'badge-err' : 'badge-warn')}">${escapeHtml(b.evidence_status)}</span></td>
              </tr>
            `).join("")}
            <tr style="background:var(--surface-alt);font-weight:700;">
              <td>TỔNG ĐIỂM</td><td>100</td><td>${sc.claimed_score}</td><td>${sc.verified_score}</td><td></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div>
        <h4 style="margin:0 0 8px; color:var(--pink-vivid);">Thông số hồ sơ &amp; Trạng thái xác minh</h4>
        <table>
          <tbody>
            <tr><th>Diện tích trưng bày</th><td>${p.showroom_area_m2 !== null ? p.showroom_area_m2 + " m2" : "<em>Thiếu dữ liệu</em>"}</td></tr>
            <tr><th>Kỹ thuật viên bảo hành</th><td>${p.warranty_technicians !== null ? p.warranty_technicians + " KTV" : "<em>Thiếu dữ liệu</em>"}</td></tr>
            <tr><th>Kế hoạch nhập hàng</th><td>${p.monthly_purchase_vnd_million !== null ? p.monthly_purchase_vnd_million + " triệu/tháng" : "<em>Thiếu dữ liệu</em>"}</td></tr>
            <tr><th>Công nợ / Hỗ trợ đề nghị</th><td>${p.requested_credit_days ?? "?"} ngày | ${p.requested_credit_limit_vnd_million ?? "?"} triệu | HT ${p.requested_marketing_support_pct ?? "?"}%</td></tr>
            <tr><th>Xác minh độc lập</th><td>POS: <code>${escapeHtml(v.pos_verified)}</code> | BH: <code>${escapeHtml(v.warranty_verified)}</code> | TC: <code>${escapeHtml(v.financial_verified)}</code></td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="grid-2" style="margin-bottom:14px;">
      <div>
        <h4 style="margin:0 0 6px; color:var(--err-fg);">Điều kiện chưa đạt &amp; Xung đột</h4>
        <ul>${(d.failed_and_conflict_items && d.failed_and_conflict_items.length) ? d.failed_and_conflict_items.map((x) => `<li>${escapeHtml(x)}</li>`).join("") : "<li>Không phát hiện vi phạm / xung đột.</li>"}</ul>

        <h4 style="margin:10px 0 6px; color:var(--warn-fg);">Thông tin thiếu / chưa xác định</h4>
        <ul>${(d.unknown_or_missing_items && d.unknown_or_missing_items.length) ? d.unknown_or_missing_items.map((x) => `<li>${escapeHtml(x)}</li>`).join("") : "<li>Đầy đủ trường thông tin cơ bản.</li>"}</ul>
      </div>
      <div>
        <h4 style="margin:0 0 6px; color:var(--pink-vivid);">Thông tin cần xác minh</h4>
        <ul>${(d.verification_tasks && d.verification_tasks.length) ? d.verification_tasks.map((t) => `<li><strong>[${escapeHtml(t.department)}]</strong> ${escapeHtml(t.task)}</li>`).join("") : "<li>Đã hoàn tất xác minh các hạng mục bắt buộc.</li>"}</ul>

        <h4 style="margin:10px 0 6px; color:var(--pink-vivid);">Căn cứ trích xuất từ nguồn</h4>
        <ul style="font-size:0.82rem;max-height:170px;overflow-y:auto;">${(d.evidence_basis || []).map((e) => `<li>${escapeHtml(e)}</li>`).join("")}</ul>
      </div>
    </div>

    <div>
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
        <h4 style="margin:0; color:var(--pink-vivid);">Bản nháp trao đổi với đối tác (${escapeHtml(app.draft.to_email || "Chưa có email")})</h4>
        <button class="btn btn-soft-pink btn-sm" onclick="copyCurrentDraft()">Sao chép bản nháp</button>
      </div>
      <div style="font-size:0.85rem; margin-bottom:6px;"><strong>Tiêu đề:</strong> ${escapeHtml(app.draft.subject)}</div>
      <pre class="draft-box" id="draftBodyPreview">${escapeHtml(app.draft.body)}</pre>
    </div>
  `;
}

window.copyCurrentDraft = async function() {
  const txt = document.getElementById("draftBodyPreview").textContent;
  try {
    await navigator.clipboard.writeText(txt);
    alert("Đã sao chép nội dung bản nháp!");
  } catch {
    alert("Không thể tự động sao chép, vui lòng bôi đen để copy.");
  }
};

function renderEscalationsTab(list) {
  const el = document.getElementById("escalationsContainer");
  if (!list.length) {
    el.innerHTML = '<div class="card">Không có trường hợp ngoại lệ nào cần chuyển thẩm quyền.</div>';
    return;
  }
  el.innerHTML = list.map((item) => `
    <div class="card">
      <div class="card-header">
        <h3 class="card-title">${escapeHtml(item.applicant_id)} — ${escapeHtml(item.partner_name)} (${escapeHtml(item.region)})</h3>
        <div>
          <span class="badge badge-neutral">Điểm thực chứng: ${item.verified_score} / Tự khai: ${item.claimed_score}</span>
          <span class="badge badge-hold">${escapeHtml(item.recommendation)}</span>
        </div>
      </div>
      <table>
        <thead><tr><th>Mã quy tắc</th><th>Loại ngoại lệ</th><th>Chuyển người có thẩm quyền</th><th>Chi tiết căn cứ</th></tr></thead>
        <tbody>
          ${(item.escalations || []).map((e) => `
            <tr>
              <td><code>${escapeHtml(e.code)}</code></td>
              <td><strong>${escapeHtml(e.label)}</strong></td>
              <td><span class="badge badge-hold">${escapeHtml(e.escalate_to)}</span></td>
              <td>${escapeHtml(e.detail)}</td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    </div>
  `).join("");
}

function renderVerificationPlan(plan) {
  const filter = document.getElementById("deptFilter").value;
  const rows = filter === "ALL" ? plan : plan.filter((x) => x.department === filter);
  const el = document.getElementById("verificationContainer");
  if (!rows.length) {
    el.innerHTML = "<p class=\"muted-text\">Không có nhiệm vụ xác minh nào cho bộ phận đã chọn.</p>";
    return;
  }
  el.innerHTML = `
    <table>
      <thead><tr><th>Bộ phận phụ trách</th><th>Mã HS</th><th>Đối tác</th><th>Khu vực</th><th>Trạng thái hiện tại</th><th>Nhiệm vụ xác minh cụ thể</th></tr></thead>
      <tbody>
        ${rows.map((r) => `
          <tr>
            <td><strong>${escapeHtml(r.department)}</strong></td>
            <td>${escapeHtml(r.applicant_id)}</td>
            <td>${escapeHtml(r.partner_name)}</td>
            <td>${escapeHtml(r.region)}</td>
            <td><span class="badge badge-warn">${escapeHtml(r.current_status)}</span></td>
            <td>${escapeHtml(r.task)}</td>
          </tr>
        `).join("")}
      </tbody>
    </table>
  `;
}

document.getElementById("deptFilter").addEventListener("change", () => {
  if (currentRunData) renderVerificationPlan(currentRunData.summary.verification_plan || []);
});

function renderLogsTab(logs, applicants) {
  const appSel = document.getElementById("logApplicantFilter");
  const prevApp = appSel.value || "ALL";
  appSel.innerHTML = '<option value="ALL">Tất cả hồ sơ</option><option value="ALL_GLOBAL">ALL (Toàn cục)</option>';
  (applicants || []).forEach((a) => {
    const opt = document.createElement("option");
    opt.value = a.profile.applicant_id;
    opt.textContent = a.profile.applicant_id + " — " + a.profile.partner_name;
    appSel.appendChild(opt);
  });
  appSel.value = [...appSel.options].some((o) => o.value === prevApp) ? prevApp : "ALL";
  drawFilteredLogs(logs);
}

function drawFilteredLogs(logs) {
  const appF = document.getElementById("logApplicantFilter").value;
  const evF = document.getElementById("logEventFilter").value;
  const filtered = (logs || []).filter((l) => {
    if (appF === "ALL_GLOBAL" && l.applicant_id !== "ALL") return false;
    if (appF !== "ALL" && appF !== "ALL_GLOBAL" && l.applicant_id !== appF) return false;
    if (evF !== "ALL" && l.event_type !== evF) return false;
    return true;
  });
  const el = document.getElementById("logsContainer");
  el.innerHTML = `
    <div class="muted-text" style="font-size:0.82rem;margin-bottom:8px;">Hiển thị ${filtered.length} / ${logs.length} sự kiện nhật ký</div>
    <div style="overflow-x:auto; max-height:65vh;">
      <table>
        <thead><tr><th>#</th><th>Thời gian</th><th>Sự kiện</th><th>Kỹ năng</th><th>Công cụ</th><th>Hồ sơ</th><th>Quy tắc áp dụng</th><th>Kết quả / Chi tiết</th><th>ms</th></tr></thead>
        <tbody>
          ${filtered.map((l) => `
            <tr>
              <td>${l.seq}</td>
              <td style="white-space:nowrap;font-size:0.78rem;">${escapeHtml((l.timestamp || "").replace("T", " ").slice(0, 19))}</td>
              <td><code>${escapeHtml(l.event_type)}</code></td>
              <td style="font-size:0.8rem;">${escapeHtml(l.skill_name)}</td>
              <td><code>${escapeHtml(l.tool_name)}</code></td>
              <td><strong>${escapeHtml(l.applicant_id)}</strong></td>
              <td style="font-size:0.78rem;">${escapeHtml((l.rule_ids_applied || []).join(", "))}</td>
              <td style="font-size:0.78rem; max-width:340px; word-break:break-word;"><code>${escapeHtml(typeof l.result_summary === "string" ? l.result_summary : JSON.stringify(l.result_summary))}</code></td>
              <td>${l.duration_ms ?? 0}</td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    </div>
  `;
}

document.getElementById("logApplicantFilter").addEventListener("change", () => {
  if (currentRunData) drawFilteredLogs(currentRunData.audit_logs || []);
});
document.getElementById("logEventFilter").addEventListener("change", () => {
  if (currentRunData) drawFilteredLogs(currentRunData.audit_logs || []);
});

// Exam dataset upload & Drag-Drop
async function handleSelectedFiles(fileList) {
  pendingUploadFiles = {};
  const arr = Array.from(fileList || []);
  for (const f of arr) {
    let rel = f.webkitRelativePath ? f.webkitRelativePath.replace(/^[^/]+\//, "") : f.name;
    if (!rel && f.name) rel = f.name;
    const text = await f.text();
    pendingUploadFiles[rel] = text;
  }
  const names = Object.keys(pendingUploadFiles);
  document.getElementById("uploadedFilesPreview").innerHTML = names.length
    ? `Đã nạp <strong>${names.length}</strong> file: <code>${escapeHtml(names.slice(0, 12).join(", "))}${names.length > 12 ? "..." : ""}</code>`
    : "Chưa chọn file nào.";
  document.getElementById("runUploadedBtn").disabled = names.length === 0;
}

document.getElementById("examFolderInput").addEventListener("change", (e) => handleSelectedFiles(e.target.files));
document.getElementById("examFilesInput").addEventListener("change", (e) => handleSelectedFiles(e.target.files));

const dropzoneEl = document.getElementById("examDropzone");
if (dropzoneEl) {
  dropzoneEl.addEventListener("dragover", (e) => {
    e.preventDefault();
    dropzoneEl.classList.add("dragover");
  });
  dropzoneEl.addEventListener("dragleave", () => {
    dropzoneEl.classList.remove("dragover");
  });
  dropzoneEl.addEventListener("drop", (e) => {
    e.preventDefault();
    dropzoneEl.classList.remove("dragover");
    if (e.dataTransfer && e.dataTransfer.files) {
      handleSelectedFiles(e.dataTransfer.files);
    }
  });
}

document.getElementById("runUploadedBtn").addEventListener("click", async () => {
  const btn = document.getElementById("runUploadedBtn");
  btn.disabled = true;
  btn.textContent = "Đang nạp & chạy...";
  try {
    let rulesOverride = null;
    const rulesTxt = document.getElementById("rulesEditor").value.trim();
    if (rulesTxt) rulesOverride = JSON.parse(rulesTxt);

    let schemaOverride = null;
    const schemaTxt = document.getElementById("schemaEditor").value.trim();
    if (schemaTxt) schemaOverride = JSON.parse(schemaTxt);

    const payload = {
      files: pendingUploadFiles,
      rules_override: rulesOverride,
      schema_override: schemaOverride,
      mode: document.getElementById("modeSelect").value,
      llm_provider: document.getElementById("providerSelect").value,
      model_name: document.getElementById("modelNameInput").value.trim(),
      api_key: document.getElementById("apiKeyInput").value.trim()
    };
    const data = await apiPost("/api/run-uploaded", payload);
    renderRunResult(data);
    const runsData = await apiGet("/api/runs");
    refreshPastRunsSelect(runsData.runs || []);
    switchTab("tab-overview");
  } catch (err) {
    alert("Lỗi chạy dữ liệu thi: " + err.message);
  } finally {
    btn.disabled = false;
    btn.textContent = "Nạp & Chạy trực tiếp dữ liệu thi";
  }
});

document.getElementById("saveRulesBtn").addEventListener("click", async () => {
  try {
    const parsed = JSON.parse(document.getElementById("rulesEditor").value);
    await apiPost("/api/config", { rules: parsed });
    alert("Đã lưu cấu hình rules_config.json thành công!");
  } catch (err) {
    alert("JSON không hợp lệ hoặc lỗi lưu: " + err.message);
  }
});

document.getElementById("saveSchemaBtn").addEventListener("click", async () => {
  try {
    const parsed = JSON.parse(document.getElementById("schemaEditor").value);
    await apiPost("/api/config", { schema: parsed });
    alert("Đã lưu ánh xạ schema_mapping.json thành công!");
  } catch (err) {
    alert("JSON không hợp lệ hoặc lỗi lưu: " + err.message);
  }
});

async function runTestsAction() {
  const btn1 = document.getElementById("runTestsBtn");
  const btn2 = document.getElementById("runTestsTabBtn");
  if (btn1) btn1.disabled = true;
  if (btn2) btn2.disabled = true;
  try {
    const res = await apiPost("/api/run-tests", {});
    switchTab("tab-tests");
    renderTestsResult(res);
  } catch (err) {
    alert("Lỗi chạy kiểm thử: " + err.message);
  } finally {
    if (btn1) btn1.disabled = false;
    if (btn2) btn2.disabled = false;
  }
}

function renderTestsResult(res) {
  const el = document.getElementById("testsContainer");
  const allOk = res.failed === 0;
  el.innerHTML = `
    <div class="alert-box ${allOk ? "alert-info" : "alert-err"}">
      <strong>Tổng kết kiểm thử:</strong> ${res.passed} / ${res.total} assertions ĐẠT (${res.failed} lỗi).
    </div>
    <table>
      <thead><tr><th>Nhóm kịch bản</th><th>Mã kiểm thử</th><th>Mô tả</th><th>Kết quả</th><th>Chi tiết quan sát</th></tr></thead>
      <tbody>
        ${(res.cases || []).map((c) => `
          <tr>
            <td><strong>${escapeHtml(c.category)}</strong></td>
            <td><code>${escapeHtml(c.test_id)}</code></td>
            <td>${escapeHtml(c.description)}</td>
            <td><span class="badge ${c.passed ? "badge-ok" : "badge-err"}">${c.passed ? "PASS" : "FAIL"}</span></td>
            <td style="font-size:0.82rem;">${escapeHtml(c.detail)}</td>
          </tr>
        `).join("")}
      </tbody>
    </table>
  `;
}

/* ==================== WIRE EXTRA UI CONTROLS ==================== */
document.getElementById("runAgentBtn").addEventListener("click", executeAgentRun);
document.getElementById("runTestsBtn").addEventListener("click", runTestsAction);
document.getElementById("runTestsTabBtn").addEventListener("click", runTestsAction);
document.getElementById("pastRunsSelect").addEventListener("change", (e) => loadSavedRun(e.target.value));
document.getElementById("downloadJsonBtn").addEventListener("click", () => {
  if (!currentRunData) return;
  const blob = new Blob([JSON.stringify(currentRunData, null, 2)], { type: "application/json;charset=utf-8" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `${currentRunData.run_id || "ket_qua"}_dai_thanh.json`;
  a.click();
});

const toggleAiBtn = document.getElementById("toggleAiConfigBtn");
const aiDrawer = document.getElementById("aiConfigDrawer");
if (toggleAiBtn && aiDrawer) {
  toggleAiBtn.addEventListener("click", () => aiDrawer.classList.toggle("hidden"));
}
document.getElementById("modeSelect").addEventListener("change", (e) => {
  if (e.target.value === "llm" && aiDrawer) aiDrawer.classList.remove("hidden");
});

const overviewSearchEl = document.getElementById("overviewSearchInput");
if (overviewSearchEl) {
  overviewSearchEl.addEventListener("input", () => renderOverviewWorkspace());
}

const heroRunBtn = document.getElementById("heroRunBtn");
if (heroRunBtn) heroRunBtn.addEventListener("click", executeAgentRun);

const heroDetailBtn = document.getElementById("heroDetailBtn");
if (heroDetailBtn) {
  heroDetailBtn.addEventListener("click", () => {
    if (selectedApplicantId) openApplicantDetail(selectedApplicantId);
    else switchTab("tab-dossiers");
  });
}

const jumpFullBtn = document.getElementById("jumpFullDossierBtn");
if (jumpFullBtn) {
  jumpFullBtn.addEventListener("click", () => {
    if (selectedApplicantId) openApplicantDetail(selectedApplicantId);
    else switchTab("tab-dossiers");
  });
}

const heroSettingsBtn = document.getElementById("heroSettingsBtn");
if (heroSettingsBtn) {
  heroSettingsBtn.addEventListener("click", () => switchTab("tab-exam"));
}

const heroFlowBtn = document.getElementById("heroFlowBtn");
if (heroFlowBtn) {
  heroFlowBtn.addEventListener("click", () => switchTab("tab-flowchart"));
}

const heroSwapBtn = document.getElementById("heroSwapBtn");
if (heroSwapBtn) {
  heroSwapBtn.addEventListener("click", () => {
    chartMode = chartMode === "applicants" ? "regions" : "applicants";
    if (currentRunData) renderHeroCard(currentRunData.applicants || []);
  });
}

const modeListBtn = document.getElementById("modeListBtn");
const modeQueueBtn = document.getElementById("modeQueueBtn");
const overviewListContainer = document.getElementById("overviewListContainer");
const overviewQueueContainer = document.getElementById("overviewQueueContainer");
if (modeListBtn && modeQueueBtn && overviewListContainer && overviewQueueContainer) {
  modeListBtn.addEventListener("click", () => {
    modeListBtn.classList.add("active");
    modeQueueBtn.classList.remove("active");
    overviewListContainer.classList.remove("hidden");
    overviewQueueContainer.classList.add("hidden");
  });
  modeQueueBtn.addEventListener("click", () => {
    modeQueueBtn.classList.add("active");
    modeListBtn.classList.remove("active");
    overviewQueueContainer.classList.remove("hidden");
    overviewListContainer.classList.add("hidden");
  });
}

/* ==================== LARK BASE FLOWCHART INTERACTION ==================== */
const flowchartMeta = {
  larkbase: {
    title: "1. LARK BASE — Nguồn dữ liệu Đại Thành",
    text: "Tiếp nhận ~30 hồ sơ/tháng tại 3 khu vực (Miền Bắc, Miền Trung, Miền Nam): applicants.json/.csv + dossiers/*.txt, existing_partners.csv, existing_pos.csv, verification_results.csv cùng rules_config.json & schema_mapping.json. Ghi SHA-256 kiểm toàn vẹn trước khi sang Cleaning.",
    targetTab: "tab-exam",
    targetLabel: "Mở Tab Nạp dữ liệu & Quy tắc →"
  },
  cleaning: {
    title: "2. CLEANING — Chuẩn hóa & Trích xuất (Tool 1)",
    text: "tool_load_and_extract_dossier đọc văn bản & JSON/CSV, ánh xạ đa bí danh từ schema_mapping.json (ma_ho_so, mst, ke_hoach_nhap_hang_trieu...), chuẩn hóa tiếng Việt không dấu, lưu nguyên văn trích dẫn evidence_quotes và đánh dấu missing_fields.",
    targetTab: "tab-exam",
    targetLabel: "Mở Ánh xạ Schema →"
  },
  error: {
    title: "LỖI — Dữ liệu chưa đạt cấu trúc (Nhánh KO)",
    text: "Bắt các lỗi thiếu bảng nguồn, sai JSON/CSV/UTF-8 hoặc mất khóa định danh; cảnh báo trả về nguồn Lark Base / bộ dữ liệu gốc — tuyệt đối không tự sửa dữ liệu test hay điền tay kết luận.",
    targetTab: "tab-exam",
    targetLabel: "Kiểm tra lại dữ liệu nạp →"
  },
  process: {
    title: "3. PROCESS — AI Agent 3 Kỹ năng & 7 Công cụ",
    text: "Chạy Gemini/OpenAI Tool Calling hoặc Hybrid Local Offline: Skill 1 (MST, tên >=82%, GPS Haversine <=5.0km, >=40m2, >=1 KTV, >=150tr, nợ <=30ng/500tr/5%) -> Skill 2 (chấm 4 tiêu chí 25-30-20-25 có trần thực chứng, cảnh báo cam kết >=400tr, xếp P1/P2/P3/HOLD/REJECT) -> Skill 3 (soạn nháp & TH 3 khu vực) kèm Audit .jsonl.",
    targetTab: "tab-logs",
    targetLabel: "Xem Nhật ký Audit Trail →"
  },
  verify: {
    title: "4. VERIFY — Kiểm soát Bất biến & HITL 1–3",
    text: "Kiểm tra bất biến cấm xếp Tiếp tục khi còn IDENTITY_DUPLICATE, TERRITORY_CONFLICT, POLICY_EXCEEDED hoặc MISSING_EVIDENCE. Con người kiểm soát: HITL-1 (Kinh doanh & Tài chính), HITL-2 (Vận hành thực địa POS/KTV), HITL-3 (Trưởng phòng PTKD duyệt cuối).",
    targetTab: "tab-escalations",
    targetLabel: "Xem Ca chuyển thẩm quyền →"
  },
  feedback: {
    title: "FEEDBACK — Phối hợp Xác minh & Tái xử lý (Nhánh KO)",
    text: "Xuất nhiệm vụ qua ke_hoach_xac_minh.csv gửi Kinh doanh – Vận hành – Tài chính và gửi bản nháp yêu cầu đối tác bổ sung. Sau khi cập nhật kết quả xác minh hoặc phê duyệt ngoại lệ, vòng ngược lên Process để tái đánh giá.",
    targetTab: "tab-verification",
    targetLabel: "Mở Kế hoạch Xác minh →"
  },
  export: {
    title: "5. XUẤT (HTML) — Kết xuất & Kiểm thử 10/10",
    text: "Đóng gói kết quả đã xác minh + Audit JSONL lên Web Server PowerShell (.NET TcpListener) tại http://localhost:8055/, đi kèm bộ 10/10 assertions tự kiểm thử (Thông thường – Thiếu dữ liệu – Biên quy tắc).",
    targetTab: "tab-tests",
    targetLabel: "Xem Bộ Tự Kiểm Thử 10/10 →"
  },
  bc: {
    title: "Đầu ra BC — Báo cáo Chi tiết & Bản nháp Email",
    text: "Tổng hợp bang_de_xuat_khu_vuc.csv, bao_cao_tong_hop.md theo 3 khu vực (Miền Bắc, Miền Trung, Miền Nam), chi tiết căn cứ – điều kiện chưa đạt từng hồ sơ, danh sách chuyển cấp và bản nháp trao đổi đối tác.",
    targetTab: "tab-regional",
    targetLabel: "Mở Bảng đề xuất 3 khu vực →"
  },
  dashboard: {
    title: "Đầu ra DASHBOARD — Kawaii Pink Web App",
    text: "Giao diện Bento tại http://localhost:8055/ hiển thị KPI, biểu đồ SVG Điểm thực chứng vs Tự khai, trạng thái Cần xác minh / Đã hoàn tất, chi tiết thẩm định timeline và nạp bộ dữ liệu thi.",
    targetTab: "tab-overview",
    targetLabel: "Về Tổng quan Dashboard →"
  }
};

function renderFlowchartNodeInfo(nodeId) {
  const box = document.getElementById("flowchartInfoBox");
  const meta = flowchartMeta[nodeId] || flowchartMeta.larkbase;
  if (!box) return;
  box.innerHTML = `
    <div style="flex:1; min-width:260px;">
      <strong style="color:var(--pink-deep);">${escapeHtml(meta.title)}:</strong>
      <span class="muted-text">${escapeHtml(meta.text)}</span>
    </div>
    <button type="button" class="btn btn-sm btn-soft-pink" onclick="switchTab('${escapeHtml(meta.targetTab)}')">${escapeHtml(meta.targetLabel)}</button>
  `;
}

function updateFlowchartLiveStats(data) {
  const el = document.getElementById("flowchartLiveSummary");
  if (!el || !data || !data.summary) return;
  const s = data.summary;
  el.innerHTML = `Phiên đang đồng bộ: <strong>${escapeHtml(data.run_id)}</strong> (<code>${escapeHtml(data.execution_mode)}</code>) — Tổng <strong>${s.total_applicants ?? 0} HS</strong> | Tiếp tục: <strong style="color:var(--ok-fg)">${s.continue_count ?? 0}</strong> | Bổ sung: <strong style="color:var(--warn-fg)">${s.supplement_count ?? 0}</strong> | Chuyển cấp: <strong style="color:var(--hold-fg)">${s.escalation_count ?? 0}</strong> | Nhật ký: <strong>${data.audit_log_count ?? 0}</strong>`;
}

document.querySelectorAll(".fc-node").forEach((node) => {
  node.addEventListener("click", () => {
    document.querySelectorAll(".fc-node").forEach((n) => n.classList.remove("selected"));
    node.classList.add("selected");
    renderFlowchartNodeInfo(node.getAttribute("data-fc-id"));
  });
});

document.querySelectorAll(".flow-filter-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    const mode = btn.getAttribute("data-flow-filter");
    document.querySelectorAll(".flow-filter-btn").forEach((b) => {
      b.classList.remove("active", "btn-pink-glass-cta");
      b.classList.add("btn-glass-subtle");
    });
    btn.classList.add("active", "btn-pink-glass-cta");
    btn.classList.remove("btn-glass-subtle");

    document.querySelectorAll(".fc-edge").forEach((edge) => {
      edge.classList.remove("dimmed");
      if (mode === "ok" && !edge.classList.contains("edge-ok")) edge.classList.add("dimmed");
      if (mode === "ko" && !edge.classList.contains("edge-ko")) edge.classList.add("dimmed");
    });
  });
});

/* ==================== CREATE DOSSIER WORKSPACE ==================== */
const CREATE_FIELD_IDS = [
  "cfApplicantId", "cfSubmittedAt", "cfPartnerName", "cfTaxId", "cfRepresentative",
  "cfPhone", "cfEmail", "cfRegion", "cfProvince", "cfDistrict", "cfWard",
  "cfLatitude", "cfLongitude", "cfPosAddress", "cfAreaM2", "cfTechCount",
  "cfPurchaseM", "cfCreditDays", "cfCreditLimit", "cfMarketingPct",
  "cfWarrantyNotes", "cfNotes"
];

let pendingAttachments = [];

const DOSSIER_JSON_KEY_MAP = {
  applicant_id: "cfApplicantId",
  ma_ho_so: "cfApplicantId",
  id: "cfApplicantId",
  submitted_at: "cfSubmittedAt",
  ngay_nop: "cfSubmittedAt",
  partner_name: "cfPartnerName",
  ten_doi_tac: "cfPartnerName",
  company_name: "cfPartnerName",
  ten_doanh_nghiep: "cfPartnerName",
  tax_id: "cfTaxId",
  mst: "cfTaxId",
  ma_so_thue: "cfTaxId",
  representative: "cfRepresentative",
  nguoi_dai_dien: "cfRepresentative",
  phone: "cfPhone",
  sdt: "cfPhone",
  dien_thoai: "cfPhone",
  hotline: "cfPhone",
  email: "cfEmail",
  region: "cfRegion",
  khu_vuc: "cfRegion",
  province: "cfProvince",
  tinh_thanh: "cfProvince",
  tinh: "cfProvince",
  district: "cfDistrict",
  quan_huyen: "cfDistrict",
  quan: "cfDistrict",
  huyen: "cfDistrict",
  ward: "cfWard",
  phuong_xa: "cfWard",
  phuong: "cfWard",
  xa: "cfWard",
  latitude: "cfLatitude",
  vi_do: "cfLatitude",
  longitude: "cfLongitude",
  kinh_do: "cfLongitude",
  pos_address: "cfPosAddress",
  dia_chi: "cfPosAddress",
  dia_chi_diem_ban: "cfPosAddress",
  address: "cfPosAddress",
  showroom_area_m2: "cfAreaM2",
  dien_tich: "cfAreaM2",
  dien_tich_m2: "cfAreaM2",
  area_m2: "cfAreaM2",
  warranty_technicians: "cfTechCount",
  so_ktv: "cfTechCount",
  ky_thuat_vien: "cfTechCount",
  tech_count: "cfTechCount",
  warranty_notes: "cfWarrantyNotes",
  ghi_chu_bao_hanh: "cfWarrantyNotes",
  monthly_purchase_vnd_million: "cfPurchaseM",
  ke_hoach_nhap_hang: "cfPurchaseM",
  doanh_so_cam_ket: "cfPurchaseM",
  purchase_m: "cfPurchaseM",
  requested_credit_days: "cfCreditDays",
  so_ngay_cong_no: "cfCreditDays",
  credit_days: "cfCreditDays",
  requested_credit_limit_vnd_million: "cfCreditLimit",
  han_muc_cong_no: "cfCreditLimit",
  credit_limit: "cfCreditLimit",
  requested_marketing_support_pct: "cfMarketingPct",
  ho_tro_marketing_pct: "cfMarketingPct",
  marketing_pct: "cfMarketingPct",
  notes: "cfNotes",
  ghi_chu: "cfNotes"
};

function formatFileSize(bytes) {
  if (bytes === undefined || bytes === null || isNaN(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return (bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : 1) + " " + units[i];
}

function getFileIcon(filename) {
  const ext = (filename || "").split(".").pop().toLowerCase();
  if (["pdf"].includes(ext)) return "📕";
  if (["png", "jpg", "jpeg", "webp", "gif"].includes(ext)) return "🖼️";
  if (["docx", "doc"].includes(ext)) return "📘";
  if (["xlsx", "xls", "csv"].includes(ext)) return "📗";
  if (["txt", "json"].includes(ext)) return "📄";
  return "📎";
}

function renderAttachmentsList() {
  const container = document.getElementById("cfAttachmentsList");
  if (!container) return;
  if (!pendingAttachments.length) {
    container.innerHTML = "";
    return;
  }
  container.innerHTML = pendingAttachments.map((att, idx) => `
    <div class="attachment-chip" title="${escapeHtml(att.name)} (${formatFileSize(att.size)})">
      <span>${getFileIcon(att.name)}</span>
      <span class="attachment-chip-name">${escapeHtml(att.name)}</span>
      <span class="attachment-chip-size">${formatFileSize(att.size)}</span>
      <button type="button" class="attachment-chip-remove" onclick="removePendingAttachment(${idx})" title="Xóa tệp này">✕</button>
    </div>
  `).join("");
}

window.removePendingAttachment = function(idx) {
  if (idx >= 0 && idx < pendingAttachments.length) {
    pendingAttachments.splice(idx, 1);
    renderAttachmentsList();
  }
};

function clearLoadedDossierBadge() {
  const badge = document.getElementById("cfLoadedFileBadge");
  if (badge) {
    badge.innerHTML = "";
    badge.classList.add("hidden");
  }
}

function showLoadedFileBadge(filename, size, extractedCount, message) {
  const badge = document.getElementById("cfLoadedFileBadge");
  if (!badge) return;
  const countText = extractedCount > 0 ? ` — Trích xuất ${extractedCount} trường` : "";
  badge.innerHTML = `
    <span>✅ <strong>${escapeHtml(filename)}</strong> (${formatFileSize(size)})${escapeHtml(countText)}${message ? ` — ${escapeHtml(message)}` : ""}</span>
    <button type="button" class="btn btn-sm btn-glass-subtle" style="padding:2px 8px; font-size:0.72rem;" onclick="clearLoadedDossierBadge()">✕</button>
  `;
  badge.classList.remove("hidden");
}

function readFileAsBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = reader.result;
      const base64 = dataUrl.split(",")[1];
      resolve(base64);
    };
    reader.onerror = (err) => reject(err);
    reader.readAsDataURL(file);
  });
}

function readFileAsText(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = (err) => reject(err);
    reader.readAsText(file, "utf-8");
  });
}

function extractFieldsFromText(text) {
  const result = {};
  if (!text) return result;

  const patterns = [
    { field: "cfApplicantId", regex: /(?:Mã\s*(?:hồ\s*sơ|đối\s*tác|ứng\s*viên)|Applicant\s*ID)[:\s]+([A-Za-z0-9_-]+)/i },
    { field: "cfPartnerName", regex: /(?:Tên\s*(?:đối\s*tác|doanh\s*nghiệp|công\s*ty|cửa\s*hàng|đơn\s*vị)|Partner\s*Name)[:\s]+([^\r\n]+)/i },
    { field: "cfTaxId", regex: /(?:Mã\s*số\s*thuế|MST|Tax\s*ID)[:\s]+([0-9]{10}(?:-[0-9]{3})?|[0-9A-Za-z-]+)/i },
    { field: "cfRepresentative", regex: /(?:Người\s*đại\s*diện|Đại\s*diện\s*pháp\s*luật|Giám\s*đốc|Chủ\s*cơ\s*sở|Representative)[:\s]+([^\r\n,;]+)/i },
    { field: "cfPhone", regex: /(?:Điện\s*thoại|SĐT|Phone|Hotline|Liên\s*hệ)[:\s]+([0-9+\s.-]{9,15})/i },
    { field: "cfEmail", regex: /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/i },
    { field: "cfRegion", regex: /(?:Khu\s*vực|Vùng|Region)[:\s]+([^\r\n,;]+)/i },
    { field: "cfProvince", regex: /(?:Tỉnh\s*\/?\s*Thành\s*phố|Tỉnh\s*thành|Tỉnh|Thành\s*phố|Province)[:\s]+([^\r\n,;]+)/i },
    { field: "cfDistrict", regex: /(?:Quận\s*\/?\s*Huyện|Quận|Huyện|Thị\s*xã|District)[:\s]+([^\r\n,;]+)/i },
    { field: "cfWard", regex: /(?:Phường\s*\/?\s*Xã|Phường|Xã|Thị\s*trấn|Ward)[:\s]+([^\r\n,;]+)/i },
    { field: "cfPosAddress", regex: /(?:Địa\s*chỉ(?:\s*điểm\s*bán|\s*showroom)?|Address)[:\s]+([^\r\n]+)/i },
    { field: "cfAreaM2", regex: /(?:Diện\s*tích(?:\s*trưng\s*bày|\s*mặt\s*bằng|\s*showroom)?|Area)[:\s]+([0-9]+(?:[.,][0-9]+)?)\s*(?:m2|m²|mét\s*vuông)?/i },
    { field: "cfTechCount", regex: /(?:(?:Số\s*)?(?:kỹ\s*thuật\s*viên|nhân\s*sự\s*kỹ\s*thuật|KTV|thợ\s*bảo\s*hành)[:\s]+([0-9]+)|([0-9]+)\s*(?:kỹ\s*thuật\s*viên|nhân\s*sự\s*kỹ\s*thuật|KTV|thợ\s*bảo\s*hành))/i },
    { field: "cfWarrantyNotes", regex: /(?:Năng\s*lực\s*bảo\s*hành|Bảo\s*hành|Warranty\s*notes?)[:\s]+([^\r\n]+)/i },
    { field: "cfPurchaseM", regex: /(?:Kế\s*hoạch\s*nhập\s*hàng|Doanh\s*số\s*cam\s*kết|Cam\s*kết\s*nhập|Monthly\s*purchase)[:\s]+([0-9]+(?:[.,][0-9]+)?)\s*(triệu|tỷ|ty|tr)?/i },
    { field: "cfCreditDays", regex: /(?:Công\s*nợ|Thời\s*gian\s*công\s*nợ|Trả\s*chậm|Credit\s*days)[:\s]+([0-9]+)\s*(?:ngày)?/i },
    { field: "cfCreditLimit", regex: /(?:Hạn\s*mức(?:\s*công\s*nợ|\s*nợ)?|Credit\s*limit)[:\s]+([0-9]+(?:[.,][0-9]+)?)\s*(triệu|tỷ|ty|tr)?/i },
    { field: "cfMarketingPct", regex: /(?:Hỗ\s*trợ(?:\s*thương\s*mại|\s*marketing|\s*trưng\s*bày)?|Chiết\s*khấu\s*hỗ\s*trợ)[:\s]+([0-9]+(?:[.,][0-9]+)?)\s*%/i },
    { field: "cfNotes", regex: /(?:Ghi\s*chú|Notes?)[:\s]+([^\r\n]+)/i }
  ];

  patterns.forEach(({ field, regex }) => {
    const match = text.match(regex);
    if (match) {
      if (field === "cfTechCount") {
        result[field] = (match[1] || match[2] || "").trim();
      } else if (field === "cfPurchaseM" || field === "cfCreditLimit") {
        let val = parseFloat((match[1] || "").replace(",", "."));
        const unit = (match[2] || "").toLowerCase();
        if (unit === "tỷ" || unit === "ty") {
          val = val * 1000;
        }
        if (!isNaN(val)) result[field] = String(val);
      } else {
        result[field] = (match[1] || "").trim();
      }
    }
  });

  return result;
}

function extractFieldsFromCsv(csvText) {
  const result = {};
  if (!csvText) return result;
  const lines = csvText.split(/\r?\n/).filter(l => l.trim().length > 0);
  if (lines.length < 2) return result;

  const parseRow = (line) => {
    const cells = [];
    let cur = "";
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (c === '"') {
        inQuotes = !inQuotes;
      } else if ((c === ',' || c === ';') && !inQuotes) {
        cells.push(cur.trim().replace(/^"(.*)"$/, '$1'));
        cur = "";
      } else {
        cur += c;
      }
    }
    cells.push(cur.trim().replace(/^"(.*)"$/, '$1'));
    return cells;
  };

  const headers = parseRow(lines[0]);
  const row1 = parseRow(lines[1]);

  headers.forEach((h, idx) => {
    const val = row1[idx];
    if (val !== undefined && val !== "") {
      const cleanH = h.toLowerCase().trim().replace(/[\s_]+/g, "_");
      const targetField = DOSSIER_JSON_KEY_MAP[cleanH];
      if (targetField) {
        result[targetField] = val;
      }
    }
  });

  return result;
}

function applyExtractedFields(fieldMap, rawContent) {
  let count = 0;
  Object.entries(fieldMap).forEach(([id, val]) => {
    if (val !== undefined && val !== null && val !== "") {
      const el = document.getElementById(id);
      if (el) {
        el.value = val;
        count++;
      }
    }
  });

  const previewEl = document.getElementById("cfRawTextPreview");
  const manualChk = document.getElementById("cfManualRawChk");
  if (rawContent && previewEl) {
    previewEl.value = rawContent;
    if (manualChk) manualChk.checked = true;
    previewEl.readOnly = false;
  } else {
    buildDossierPreviewText();
  }

  return count;
}

async function processDossierFile(file) {
  try {
    const ext = file.name.split(".").pop().toLowerCase();
    const text = await readFileAsText(file);
    let fieldMap = {};
    let rawContent = text;

    if (ext === "json") {
      try {
        const parsed = JSON.parse(text);
        const obj = Array.isArray(parsed) ? parsed[0] : (parsed.applicant || parsed.dossier || parsed);
        Object.entries(obj).forEach(([k, v]) => {
          const lowerK = k.toLowerCase().trim();
          const targetField = DOSSIER_JSON_KEY_MAP[lowerK];
          if (targetField && (typeof v === "string" || typeof v === "number")) {
            fieldMap[targetField] = String(v);
          }
        });
        if (obj.raw_text) rawContent = obj.raw_text;
        if (obj.verification) {
          applyVerificationQuickState("pass");
          if (obj.verification.identity_verified) {
            const el = document.getElementById("cfVerIdentity");
            if (el) el.value = obj.verification.identity_verified;
          }
          if (obj.verification.pos_verified) {
            const el = document.getElementById("cfVerPos");
            if (el) el.value = obj.verification.pos_verified;
          }
          if (obj.verification.warranty_verified) {
            const el = document.getElementById("cfVerWarranty");
            if (el) el.value = obj.verification.warranty_verified;
          }
          if (obj.verification.financial_verified) {
            const el = document.getElementById("cfVerFinancial");
            if (el) el.value = obj.verification.financial_verified;
          }
          if (obj.verification.verified_by) {
            const el = document.getElementById("cfVerifiedBy");
            if (el) el.value = obj.verification.verified_by;
          }
          if (obj.verification.verification_notes) {
            const el = document.getElementById("cfVerNotes");
            if (el) el.value = obj.verification.verification_notes;
          }
        }
      } catch (jsonErr) {
        throw new Error("Tệp JSON không hợp lệ: " + jsonErr.message);
      }
    } else if (ext === "csv") {
      fieldMap = extractFieldsFromCsv(text);
    } else {
      fieldMap = extractFieldsFromText(text);
    }

    const count = applyExtractedFields(fieldMap, rawContent);
    showLoadedFileBadge(file.name, file.size, count);
    setCreateStatus(`Đã nạp file ${file.name} và trích xuất thành công ${count} trường.`);
  } catch (err) {
    setCreateStatus("Lỗi đọc file hồ sơ: " + err.message, true);
  }
}

async function processAttachmentFiles(files) {
  for (const f of files) {
    if (pendingAttachments.some(a => a.name === f.name)) {
      continue;
    }
    try {
      const b64 = await readFileAsBase64(f);
      pendingAttachments.push({
        name: f.name,
        size: f.size,
        type: f.type || "application/octet-stream",
        content_base64: b64
      });
    } catch (err) {
      console.error("Lỗi đọc file đính kèm:", f.name, err);
      setCreateStatus("Lỗi đọc file đính kèm " + f.name + ": " + err.message, true);
    }
  }
  renderAttachmentsList();
  setCreateStatus(`Đã đính kèm ${pendingAttachments.length} tệp tài liệu.`);
}

const DOSSIER_PRESETS = {
  compliant: {
    data: {
      cfPartnerName: "Công ty TNHH Gia dụng Hồng Phát",
      cfTaxId: "0109991122",
      cfRepresentative: "Nguyễn Minh Anh",
      cfPhone: "0918889900",
      cfEmail: "minhanh@hongphat.vn",
      cfRegion: "Miền Bắc",
      cfProvince: "Hà Nội",
      cfDistrict: "Hà Đông",
      cfWard: "Mộ Lao",
      cfLatitude: "20.9719",
      cfLongitude: "105.7764",
      cfPosAddress: "88 Trần Phú, Mộ Lao, Hà Đông, Hà Nội",
      cfAreaM2: "120",
      cfTechCount: "3",
      cfPurchaseM: "380",
      cfCreditDays: "30",
      cfCreditLimit: "380",
      cfMarketingPct: "4",
      cfWarrantyNotes: "Phòng kỹ thuật riêng 3 KTV, bảo hành tại nhà trong bán kính 15 km",
      cfNotes: "Đã đính kèm hợp đồng thuê mặt bằng 3 năm, chứng chỉ nghề 3 KTV và BCTC 2025."
    },
    ver: "pass"
  },
  unverified: {
    data: {
      cfPartnerName: "Cửa hàng Điện máy Thăng Long",
      cfTaxId: "2400889900",
      cfRepresentative: "Lê Quốc Huy",
      cfPhone: "0977554433",
      cfEmail: "huy.le@thanglong.vn",
      cfRegion: "Miền Bắc",
      cfProvince: "Bắc Giang",
      cfDistrict: "TP Bắc Giang",
      cfWard: "Hoàng Văn Thụ",
      cfLatitude: "21.2731",
      cfLongitude: "106.1946",
      cfPosAddress: "56 Xương Giang, TP Bắc Giang, Bắc Giang",
      cfAreaM2: "",
      cfTechCount: "",
      cfPurchaseM: "950",
      cfCreditDays: "30",
      cfCreditLimit: "450",
      cfMarketingPct: "4.5",
      cfWarrantyNotes: "Cam kết sẽ tuyển thêm KTV sau khi ký hợp đồng",
      cfNotes: "Cam kết sản lượng lớn 950 triệu/tháng nhưng chưa nộp ảnh showroom và BCTC."
    },
    ver: "pending"
  },
  conflict: {
    data: {
      cfPartnerName: "Siêu thị Bếp Phương Nam",
      cfTaxId: "0318884455",
      cfRepresentative: "Trần Thanh Tú",
      cfPhone: "0908667788",
      cfEmail: "tu.tran@bepphuongnam.vn",
      cfRegion: "Miền Nam",
      cfProvince: "TP.HCM",
      cfDistrict: "Quận 4",
      cfWard: "Phường 6",
      cfLatitude: "10.7570",
      cfLongitude: "106.7040",
      cfPosAddress: "210 Bến Vân Đồn, Phường 6, Quận 4, TP.HCM",
      cfAreaM2: "110",
      cfTechCount: "2",
      cfPurchaseM: "520",
      cfCreditDays: "45",
      cfCreditLimit: "650",
      cfMarketingPct: "7",
      cfWarrantyNotes: "Trạm kỹ thuật 2 KTV chuyên thiết bị bếp",
      cfNotes: "Đề nghị công nợ 45 ngày, hạn mức 650 triệu, hỗ trợ 7%; điểm bán gần Quận 7 (~3 km)."
    },
    ver: "pass"
  },
  clear: {
    data: {},
    ver: "pending"
  }
};

function getVal(id) {
  const el = document.getElementById(id);
  return el ? el.value.trim() : "";
}

function buildDossierPreviewText() {
  const previewEl = document.getElementById("cfRawTextPreview");
  const manualChk = document.getElementById("cfManualRawChk");
  if (!previewEl || (manualChk && manualChk.checked)) return;

  const lines = ["HỒ SƠ ĐĂNG KÝ ĐỐI TÁC PHÂN PHỐI - ĐẠI THÀNH"];
  const textPairs = [
    ["Mã hồ sơ", getVal("cfApplicantId")],
    ["Tên đối tác", getVal("cfPartnerName")],
    ["Mã số thuế", getVal("cfTaxId")],
    ["Người đại diện", getVal("cfRepresentative")],
    ["Điện thoại", getVal("cfPhone")],
    ["Email", getVal("cfEmail")],
    ["Khu vực", getVal("cfRegion")],
    ["Tỉnh/Thành", getVal("cfProvince")],
    ["Quận/Huyện", getVal("cfDistrict")],
    ["Phường/Xã", getVal("cfWard")],
    ["Địa chỉ điểm bán", getVal("cfPosAddress")]
  ];
  textPairs.forEach(([label, val]) => {
    if (val) lines.push(`${label}: ${val}`);
  });

  const area = getVal("cfAreaM2");
  if (area) lines.push(`Diện tích trưng bày: ${area} m2`);

  const tech = getVal("cfTechCount");
  const wNotes = getVal("cfWarrantyNotes");
  if (tech || wNotes) {
    const parts = [];
    if (tech) parts.push(`Có ${tech} kỹ thuật viên`);
    if (wNotes) parts.push(wNotes);
    lines.push(`Năng lực bảo hành: ${parts.join("; ")}`);
  }

  const purch = getVal("cfPurchaseM");
  if (purch) lines.push(`Kế hoạch nhập hàng: ${purch} triệu đồng/tháng`);

  const cDays = getVal("cfCreditDays");
  const cLim = getVal("cfCreditLimit");
  const mkt = getVal("cfMarketingPct");
  const commParts = [];
  if (cDays) commParts.push(`Công nợ ${cDays} ngày`);
  if (cLim) commParts.push(`hạn mức công nợ ${cLim} triệu đồng`);
  if (mkt) commParts.push(`hỗ trợ thương mại ${mkt}%`);
  if (commParts.length) lines.push(`Yêu cầu hỗ trợ thương mại: ${commParts.join(", ")}`);

  const notes = getVal("cfNotes");
  if (notes) lines.push(`Ghi chú: ${notes}`);

  previewEl.value = lines.join("\n");
}

function applyVerificationQuickState(mode) {
  const chk = document.getElementById("cfIncludeVerification");
  const box = document.getElementById("cfVerificationFields");
  const ids = ["cfVerIdentity", "cfVerPos", "cfVerWarranty", "cfVerFinancial"];
  const byEl = document.getElementById("cfVerifiedBy");
  const noteEl = document.getElementById("cfVerNotes");

  if (mode === "none") {
    if (chk) chk.checked = false;
  } else {
    if (chk) chk.checked = true;
    const val = mode === "pass" ? "VERIFIED_PASS" : "PENDING";
    ids.forEach((id) => {
      const el = document.getElementById(id);
      if (el) el.value = val;
    });
    if (byEl) byEl.value = mode === "pass" ? "Kinh doanh + Vận hành + Tài chính" : "Kinh doanh";
    if (noteEl) {
      noteEl.value = mode === "pass"
        ? "Đã khảo sát thực địa showroom, KTV bảo hành và hồ sơ tài chính đạt chuẩn."
        : "Đang chờ bộ phận Vận hành và Tài chính xác minh thực tế.";
    }
  }
  if (box && chk) {
    box.style.opacity = chk.checked ? "1" : "0.45";
    box.style.pointerEvents = chk.checked ? "auto" : "none";
  }
}

function applyCreatePreset(key) {
  if (key === "clear") {
    pendingAttachments = [];
    renderAttachmentsList();
    clearLoadedDossierBadge();
    const dInput = document.getElementById("cfDossierFileInput");
    if (dInput) dInput.value = "";
    const aInput = document.getElementById("cfAttachmentsInput");
    if (aInput) aInput.value = "";
  }
  const preset = DOSSIER_PRESETS[key];
  if (!preset) return;
  CREATE_FIELD_IDS.forEach((id) => {
    if (id === "cfApplicantId" || id === "cfSubmittedAt") return;
    const el = document.getElementById(id);
    if (!el) return;
    if (id === "cfRegion") {
      el.value = preset.data[id] || "Miền Bắc";
    } else {
      el.value = preset.data[id] ?? "";
    }
  });
  const manualChk = document.getElementById("cfManualRawChk");
  const previewEl = document.getElementById("cfRawTextPreview");
  if (manualChk) manualChk.checked = false;
  if (previewEl) previewEl.readOnly = true;
  applyVerificationQuickState(preset.ver);
  buildDossierPreviewText();
}

function setCreateStatus(message, isError = false) {
  const el = document.getElementById("createStatusBanner");
  if (!el) return;
  el.className = `alert-box ${isError ? "alert-err" : "alert-info"}`;
  el.textContent = message;
  el.classList.remove("hidden");
}

async function loadTargetDatasetDossiers(preserveCurrentId = false) {
  const dsInput = document.getElementById("createDatasetName");
  const listEl = document.getElementById("customDatasetDossiersList");
  const labelEl = document.getElementById("customDatasetLabel");
  const countEl = document.getElementById("customDatasetCount");
  const idInput = document.getElementById("cfApplicantId");
  const dsName = (dsInput && dsInput.value.trim()) ? dsInput.value.trim() : "custom_dossiers";

  if (labelEl) labelEl.textContent = dsName;
  try {
    const info = await apiGet("/api/dossiers/" + encodeURIComponent(dsName));
    if (countEl) countEl.textContent = info.count ?? 0;
    if (idInput && !preserveCurrentId && info.next_id) {
      idInput.value = info.next_id;
      buildDossierPreviewText();
    }
    if (!listEl) return;
    const items = info.items || [];
    if (!items.length) {
      listEl.innerHTML = `<div class="empty-card-hint">Bộ dữ liệu <code>${escapeHtml(dsName)}</code> chưa có hồ sơ nào. Hãy tạo hồ sơ đầu tiên ở bên trái!</div>`;
      return;
    }
    listEl.innerHTML = items.map((it) => `
      <div class="custom-dossier-row">
        <div style="min-width:0;">
          <div style="font-weight:800; font-size:0.84rem; color:#ffffff; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
            <code>${escapeHtml(it.applicant_id)}</code> — ${escapeHtml(it.partner_name || "(Chưa rõ tên)")}
          </div>
          <div class="muted-text" style="font-size:0.74rem;">${escapeHtml(it.region || "Chưa rõ khu vực")} · ${escapeHtml(it.submitted_at || "")}</div>
          ${it.attachment_files && it.attachment_files.length ? `
            <div style="margin-top:5px; display:flex; flex-wrap:wrap; gap:4px;">
              ${it.attachment_files.map(fn => `
                <a href="/api/attachments/${encodeURIComponent(dsName)}/${encodeURIComponent(it.applicant_id)}/${encodeURIComponent(fn)}" target="_blank" class="attachment-chip" style="padding:2px 7px; font-size:0.68rem; text-decoration:none; cursor:pointer;" title="Mở / Tải tệp ${escapeHtml(fn)}">
                  <span>${getFileIcon(fn)}</span>
                  <span class="attachment-chip-name" style="max-width:110px;">${escapeHtml(fn)}</span>
                </a>
              `).join("")}
            </div>
          ` : ""}
        </div>
        ${info.is_protected
          ? '<span class="badge badge-neutral">Chuẩn (Chỉ đọc)</span>'
          : `<button type="button" class="btn btn-sm btn-glass-subtle" onclick="deleteCustomDossier('${escapeHtml(dsName)}', '${escapeHtml(it.applicant_id)}')">Xóa</button>`}
      </div>
    `).join("");
  } catch (err) {
    if (listEl) {
      listEl.innerHTML = `<div class="empty-card-hint">Không đọc được danh sách (${escapeHtml(err.message)})</div>`;
    }
  }
}

window.deleteCustomDossier = async function(datasetName, applicantId) {
  if (!confirm(`Xóa hồ sơ ${applicantId} khỏi bộ dữ liệu ${datasetName}?`)) return;
  try {
    await apiPost("/api/dossiers/delete", { dataset_name: datasetName, applicant_id: applicantId });
    setCreateStatus(`Đã xóa hồ sơ ${applicantId} khỏi ${datasetName}.`);
    await loadTargetDatasetDossiers(false);
  } catch (err) {
    setCreateStatus("Lỗi xóa hồ sơ: " + err.message, true);
  }
};

async function saveDossierAction(runAfter) {
  const dsName = getVal("createDatasetName") || "custom_dossiers";
  const appId = getVal("cfApplicantId");
  const partnerName = getVal("cfPartnerName");
  const rawText = (document.getElementById("cfRawTextPreview")?.value || "").trim();

  if (!appId) {
    setCreateStatus("Vui lòng nhập Mã hồ sơ (chữ, số, '-' hoặc '_').", true);
    return;
  }
  if (!partnerName && !rawText) {
    setCreateStatus("Vui lòng nhập Tên đối tác hoặc nội dung hồ sơ văn bản.", true);
    return;
  }

  const btn1 = document.getElementById("createAndRunBtn");
  const btn2 = document.getElementById("createOnlyBtn");
  [btn1, btn2].forEach((b) => { if (b) b.disabled = true; });

  try {
    const includeVer = Boolean(document.getElementById("cfIncludeVerification")?.checked);
    const payload = {
      dataset_name: dsName,
      base_dataset: document.getElementById("createBaseDataset")?.value || "sample_exam_pack",
      include_sample_applicants: Boolean(document.getElementById("createIncludeSampleChk")?.checked),
      overwrite: Boolean(document.getElementById("createOverwriteChk")?.checked),
      applicant_id: appId,
      submitted_at: getVal("cfSubmittedAt"),
      partner_name: partnerName,
      tax_id: getVal("cfTaxId"),
      representative: getVal("cfRepresentative"),
      phone: getVal("cfPhone"),
      email: getVal("cfEmail"),
      region: getVal("cfRegion"),
      province: getVal("cfProvince"),
      district: getVal("cfDistrict"),
      ward: getVal("cfWard"),
      pos_address: getVal("cfPosAddress"),
      latitude: getVal("cfLatitude"),
      longitude: getVal("cfLongitude"),
      showroom_area_m2: getVal("cfAreaM2"),
      warranty_technicians: getVal("cfTechCount"),
      warranty_notes: getVal("cfWarrantyNotes"),
      monthly_purchase_vnd_million: getVal("cfPurchaseM"),
      requested_credit_days: getVal("cfCreditDays"),
      requested_credit_limit_vnd_million: getVal("cfCreditLimit"),
      requested_marketing_support_pct: getVal("cfMarketingPct"),
      notes: getVal("cfNotes"),
      raw_text: rawText,
      attachments: pendingAttachments.map(a => ({
        name: a.name,
        size: a.size,
        content_base64: a.content_base64
      })),
      include_verification: includeVer,
      verification: includeVer ? {
        identity_verified: document.getElementById("cfVerIdentity")?.value || "NOT_SUBMITTED",
        pos_verified: document.getElementById("cfVerPos")?.value || "NOT_SUBMITTED",
        warranty_verified: document.getElementById("cfVerWarranty")?.value || "NOT_SUBMITTED",
        financial_verified: document.getElementById("cfVerFinancial")?.value || "NOT_SUBMITTED",
        verified_by: getVal("cfVerifiedBy"),
        verification_date: getVal("cfSubmittedAt"),
        verification_notes: getVal("cfVerNotes")
      } : null
    };

    const res = await apiPost("/api/dossiers/create", payload);
    const dsData = await apiGet("/api/datasets");
    refreshDatasetDropdowns(dsData.datasets || [], res.dataset_name);
    await loadTargetDatasetDossiers(false);
    pendingAttachments = [];
    renderAttachmentsList();
    clearLoadedDossierBadge();
    const dInput = document.getElementById("cfDossierFileInput");
    if (dInput) dInput.value = "";
    const aInput = document.getElementById("cfAttachmentsInput");
    if (aInput) aInput.value = "";
    setCreateStatus(`Đã lưu hồ sơ ${res.applicant_id} (${res.dossier_file}) vào bộ dữ liệu "${res.dataset_name}".`);

    if (runAfter) {
      selectedApplicantId = res.applicant_id;
      await executeAgentRun();
      switchTab("tab-overview");
    }
  } catch (err) {
    setCreateStatus("Không lưu được hồ sơ: " + err.message, true);
  } finally {
    [btn1, btn2].forEach((b) => { if (b) b.disabled = false; });
  }
}

["openCreateDossierBtn", "dossiersCreateBtn"].forEach((id) => {
  const btn = document.getElementById(id);
  if (btn) btn.addEventListener("click", () => switchTab("tab-create"));
});

const presetMap = {
  presetCompliantBtn: "compliant",
  presetUnverifiedBtn: "unverified",
  presetConflictBtn: "conflict",
  presetClearBtn: "clear"
};
Object.entries(presetMap).forEach(([btnId, key]) => {
  const el = document.getElementById(btnId);
  if (el) el.addEventListener("click", () => applyCreatePreset(key));
});

const verBtnMap = {
  verAllPassBtn: "pass",
  verPendingBtn: "pending",
  verNoneBtn: "none"
};
Object.entries(verBtnMap).forEach(([btnId, mode]) => {
  const el = document.getElementById(btnId);
  if (el) el.addEventListener("click", () => applyVerificationQuickState(mode));
});

const incVerChk = document.getElementById("cfIncludeVerification");
if (incVerChk) {
  incVerChk.addEventListener("change", () => {
    const box = document.getElementById("cfVerificationFields");
    if (box) {
      box.style.opacity = incVerChk.checked ? "1" : "0.45";
      box.style.pointerEvents = incVerChk.checked ? "auto" : "none";
    }
  });
}

const manualRawChk = document.getElementById("cfManualRawChk");
if (manualRawChk) {
  manualRawChk.addEventListener("change", () => {
    const previewEl = document.getElementById("cfRawTextPreview");
    if (previewEl) previewEl.readOnly = !manualRawChk.checked;
    if (!manualRawChk.checked) buildDossierPreviewText();
  });
}

CREATE_FIELD_IDS.forEach((id) => {
  const el = document.getElementById(id);
  if (el) {
    el.addEventListener("input", buildDossierPreviewText);
    el.addEventListener("change", buildDossierPreviewText);
  }
});

const dsNameInput = document.getElementById("createDatasetName");
if (dsNameInput) {
  dsNameInput.addEventListener("change", () => loadTargetDatasetDossiers(false));
}
const refreshCustomBtn = document.getElementById("refreshCustomListBtn");
if (refreshCustomBtn) {
  refreshCustomBtn.addEventListener("click", () => loadTargetDatasetDossiers(false));
}
const createAndRunBtn = document.getElementById("createAndRunBtn");
if (createAndRunBtn) createAndRunBtn.addEventListener("click", () => saveDossierAction(true));
const createOnlyBtn = document.getElementById("createOnlyBtn");
if (createOnlyBtn) createOnlyBtn.addEventListener("click", () => saveDossierAction(false));

const cfDossierInput = document.getElementById("cfDossierFileInput");
if (cfDossierInput) {
  cfDossierInput.addEventListener("change", async (e) => {
    const f = e.target.files?.[0];
    if (f) await processDossierFile(f);
    e.target.value = "";
  });
}

const cfAttachmentsInput = document.getElementById("cfAttachmentsInput");
if (cfAttachmentsInput) {
  cfAttachmentsInput.addEventListener("change", async (e) => {
    const files = Array.from(e.target.files || []);
    if (files.length) await processAttachmentFiles(files);
    e.target.value = "";
  });
}

const dropzone = document.getElementById("createDossierDropzone");
if (dropzone) {
  ["dragenter", "dragover"].forEach((evt) => {
    dropzone.addEventListener(evt, (e) => {
      e.preventDefault();
      e.stopPropagation();
      dropzone.classList.add("dragover");
    });
  });

  ["dragleave", "dragend"].forEach((evt) => {
    dropzone.addEventListener(evt, (e) => {
      e.preventDefault();
      e.stopPropagation();
      dropzone.classList.remove("dragover");
    });
  });

  dropzone.addEventListener("drop", async (e) => {
    e.preventDefault();
    e.stopPropagation();
    dropzone.classList.remove("dragover");
    const files = Array.from(e.dataTransfer?.files || []);
    if (!files.length) return;

    const dossierFiles = [];
    const attachmentFiles = [];

    files.forEach((f) => {
      const ext = (f.name || "").split(".").pop().toLowerCase();
      if (["txt", "json", "csv"].includes(ext) && !dossierFiles.length) {
        dossierFiles.push(f);
      } else {
        attachmentFiles.push(f);
      }
    });

    if (dossierFiles.length) {
      await processDossierFile(dossierFiles[0]);
    }
    if (attachmentFiles.length) {
      await processAttachmentFiles(attachmentFiles);
    }
  });
}

buildDossierPreviewText();
renderFlowchartNodeInfo("larkbase");
initApp();
