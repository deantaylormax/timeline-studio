(function () {
  const events = [
    {
      lane: 0,
      at: 8,
      clock: "Feb 4, 2026 at 8:12 AM",
      iso: "2026-02-04T08:12",
      time: "Feb 4 at 8:12 AM",
      short: "Demand letter",
      kicker: "Email",
      tint: "#5856D6",
      title: "Demand letter from counsel",
      notes: "Henderson’s lawyer gives Acme 14 days on the withheld February payment.",
      file: "Demand-letter.pdf · p. 1"
    },
    {
      lane: 2,
      at: 22,
      clock: "Feb 6, 2026 at 10:00 AM",
      iso: "2026-02-06T10:00",
      time: "Feb 6 at 10:00 AM",
      short: "Site walkthrough",
      kicker: "Meeting",
      tint: "#FF9500",
      title: "Site walkthrough",
      notes: "North slab. The superintendent marks where the pour stopped. Photos taken."
    },
    {
      lane: 1,
      at: 46,
      clock: "Feb 11, 2026 at 2:15 PM",
      iso: "2026-02-11T14:15",
      time: "Feb 11 at 2:15 PM",
      short: "Superintendent",
      kicker: "Phone call",
      tint: "#34C759",
      title: "Call with the superintendent",
      notes: "12 minutes. He confirms the pour stopped on February 4."
    },
    {
      lane: 0,
      at: 64,
      clock: "Feb 14, 2026 at 9:40 AM",
      iso: "2026-02-14T09:40",
      time: "Feb 14 at 9:40 AM",
      short: "Complaint served",
      kicker: "Email",
      tint: "#5856D6",
      title: "Complaint served",
      notes: "Breach of the March 2024 purchase order. Exhibit B is the demand letter.",
      file: "Complaint.pdf · p. 3"
    },
    {
      lane: 1,
      at: 80,
      clock: "Feb 18, 2026 at 11:05 AM",
      iso: "2026-02-18T11:05",
      time: "Feb 18 at 11:05 AM",
      short: "Adjuster call",
      kicker: "Phone call",
      tint: "#34C759",
      title: "Adjuster declines the delay claim",
      notes: "The carrier will not accept an uncapped delay. 9 minutes."
    },
    {
      lane: 2,
      at: 92,
      clock: "Feb 20, 2026 at 3:30 PM",
      iso: "2026-02-20T15:30",
      time: "Feb 20 at 3:30 PM",
      short: "Mediation",
      kicker: "Meeting",
      tint: "#FF9500",
      title: "Mediation",
      notes: "No agreement. The next session is March 3."
    }
  ];

  const lanes = [
    { name: "Emails", tint: "#5856D6" },
    { name: "Calls", tint: "#34C759" },
    { name: "Meetings", tint: "#FF9500" }
  ];

  const icons = {
    0: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M3.5 6.2A2.2 2.2 0 0 1 5.7 4h12.6a2.2 2.2 0 0 1 2.2 2.2v11.6a2.2 2.2 0 0 1-2.2 2.2H5.7a2.2 2.2 0 0 1-2.2-2.2V6.2Zm1.8.3 6.7 5.1 6.7-5.1H5.3Zm13.2 1.9-6.1 4.6a.7.7 0 0 1-.8 0L5.5 8.4v9.4c0 .2.2.4.4.4h12.2c.2 0 .4-.2.4-.4V8.4Z"/></svg>',
    1: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M7.2 3.6h2c.4 0 .7.3.8.6l.7 2.3a.9.9 0 0 1-.2.9L9.1 8.7a11.2 11.2 0 0 0 6.2 6.2l1.3-1.4a.9.9 0 0 1 .9-.2l2.3.7c.3.1.6.4.6.8v2c0 .5-.4 1-1 1C11.2 18 6 12.8 6 4.6c0-.5.4-1 1-1h.2Z"/></svg>',
    2: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M8.2 11.2a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Zm7.6.3a2.2 2.2 0 1 0 0-4.4 2.2 2.2 0 0 0 0 4.4ZM3.8 17.4c.4-2.2 2.2-3.4 4.4-3.4s4 .1 4.4 3.4v.8H3.8v-.8Zm8.2-.2c.2-1.6 1.2-2.6 2.8-2.8 1.8.2 3.2 1.3 3.6 2.8v.8h-6.4v-.8Z"/></svg>'
  };

  const strip = document.getElementById("strip");
  const card = document.getElementById("focus-card");
  const stage = document.getElementById("stage");
  const counter = document.getElementById("counter");
  const clock = document.getElementById("clock");
  const fill = document.getElementById("scrub-fill");
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  lanes.forEach(function (lane, index) {
    const row = document.createElement("div");
    row.className = "lane";
    row.dataset.lane = String(index);
    row.innerHTML =
      '<div class="lane-line"></div>' +
      '<div class="lane-label" style="--c:' + lane.tint + '"><i></i>' + lane.name + "</div>";
    strip.appendChild(row);
  });

  const divider = document.createElement("div");
  divider.className = "divider";
  divider.style.left = "calc(118px + (100% - 146px) * 0.55)";
  divider.innerHTML = "<span>Suit filed</span>";
  strip.appendChild(divider);

  const nodes = events.map(function (event, index) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "node";
    button.dataset.i = String(index);
    button.style.setProperty("--c", event.tint);
    button.style.left = "calc(118px + (100% - 146px) * " + (event.at / 100) + ")";
    button.setAttribute("aria-label", event.kicker + ": " + event.title);
    button.innerHTML =
      icons[event.lane] +
      '<span class="node-title">' + event.short + "</span>" +
      '<span class="node-time">' + event.time + "</span>";
    button.addEventListener("click", function () { select(index); });
    strip.querySelector('.lane[data-lane="' + event.lane + '"]').appendChild(button);
    return button;
  });

  let current = 2;
  const params = new URLSearchParams(location.search);
  if (params.has("event")) {
    const requested = Number(params.get("event"));
    if (requested >= 0 && requested < events.length) current = requested;
  }

  function placeCard() {
    const dock = stage.clientWidth < 760;
    stage.classList.toggle("dock", dock);
    if (dock) {
      card.style.left = "";
      card.style.top = "";
      card.style.transform = "";
      return;
    }
    const node = nodes[current];
    const stageBox = stage.getBoundingClientRect();
    const nodeBox = node.getBoundingClientRect();
    const width = card.offsetWidth || 250;
    const height = card.offsetHeight || 120;
    const gutter = 132;
    const center = nodeBox.left - stageBox.left + nodeBox.width / 2;
    const gap = 16;

    function hits(left, top) {
      const right = left + width;
      const bottom = top + height;
      let count = 0;
      nodes.forEach(function (other, i) {
        if (i === current) return;
        [other, other.querySelector(".node-title"), other.querySelector(".node-time")].forEach(function (el) {
          if (!el) return;
          const box = el.getBoundingClientRect();
          const x = box.left - stageBox.left;
          const y = box.top - stageBox.top;
          const intersects = x < right + 8 && x + box.width > left - 8 && y < bottom + 8 && y + box.height > top - 8;
          if (intersects) count++;
        });
      });
      return count;
    }

    const top = Math.max(4, events[current].lane === 0
      ? nodeBox.bottom - stageBox.top + 14
      : nodeBox.top - stageBox.top - height - 14);
    const options = [center - width - gap, center + gap, center - width / 2];
    let left = options[0];
    let best = Infinity;
    options.forEach(function (option) {
      const clamped = Math.max(gutter, Math.min(stageBox.width - width - 16, option));
      const count = hits(clamped, top);
      if (count < best) {
        best = count;
        left = clamped;
      }
    });
    card.style.left = left + "px";
    card.style.top = top + "px";
    card.style.transform = "none";
  }

  function select(index, fromUser) {
    current = (index + events.length) % events.length;
    const event = events[current];
    nodes.forEach(function (node, i) {
      node.setAttribute("aria-pressed", i === current ? "true" : "false");
    });
    card.style.setProperty("--tint", event.tint);
    card.innerHTML =
      '<p class="kicker">' + event.kicker + "</p>" +
      "<h3>" + event.title + "</h3>" +
      '<p class="notes">' + event.notes + "</p>" +
      (event.file ? '<p class="file">' + event.file + "</p>" : "");
    counter.textContent = (current + 1) + " of " + events.length;
    clock.textContent = event.clock;
    clock.setAttribute("datetime", event.iso);
    fill.style.width = ((current + 1) / events.length * 100) + "%";
    if (fromUser) {
      nodes[current].scrollIntoView({
        inline: "center",
        block: "nearest",
        behavior: reduce ? "auto" : "smooth"
      });
    }
    placeCard();
  }

  document.getElementById("prev").addEventListener("click", function () { select(current - 1, true); });
  document.getElementById("next").addEventListener("click", function () { select(current + 1, true); });

  document.addEventListener("keydown", function (key) {
    const tag = document.activeElement && document.activeElement.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
    if (key.key === "ArrowRight") { key.preventDefault(); select(current + 1, true); }
    if (key.key === "ArrowLeft") { key.preventDefault(); select(current - 1, true); }
  });

  window.addEventListener("resize", function () { placeCard(); });
  document.querySelector(".scroller").addEventListener("scroll", function () { placeCard(); });

  select(current, false);
  window.addEventListener("load", function () { placeCard(); });
})();
