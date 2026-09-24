/* Shared interactions — nav + contact form (no fake backend) */
(function () {
  "use strict";

  // Mobile nav
  var toggle = document.querySelector("[data-nav-toggle]");
  var nav = document.querySelector("[data-main-nav]");
  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    nav.addEventListener("click", function (e) {
      if (e.target.closest("a")) {
        nav.classList.remove("open");
        toggle.setAttribute("aria-expanded", "false");
      }
    });
  }

  // Footer year
  document.querySelectorAll("[data-year]").forEach(function (el) {
    el.textContent = String(new Date().getFullYear());
  });

  // Contact form:
  // No backend is connected. We validate locally and offer to continue
  // via WhatsApp using ONLY the number/URL from "iletişim bilgileri.txt".
  // TODO(backend): replace handlePendingSubmit() with fetch() to real endpoint.
  var form = document.querySelector("[data-contact-form]");
  if (!form) return;

  var status = form.querySelector("[data-form-status]");
  var WA_NUMBER = form.getAttribute("data-whatsapp-number") || "905323881072";

  function setStatus(msg, kind) {
    if (!status) return;
    status.textContent = msg;
    status.classList.remove("ok", "err");
    if (kind) status.classList.add(kind);
  }

  function isEmail(v) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v);
  }

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    var name = form.querySelector("#adsoyad").value.trim();
    var phone = form.querySelector("#telefon").value.trim();
    var email = form.querySelector("#eposta").value.trim();
    var topic = form.querySelector("#konu").value;
    var msg = form.querySelector("#mesaj").value.trim();

    if (name.length < 2) {
      setStatus("Lütfen adınızı ve soyadınızı yazın.", "err");
      form.querySelector("#adsoyad").focus();
      return;
    }
    if (phone.length < 7) {
      setStatus("Lütfen ulaşılabilir bir telefon numarası yazın.", "err");
      form.querySelector("#telefon").focus();
      return;
    }
    if (email && !isEmail(email)) {
      setStatus("E-posta adresi hatalı görünüyor. Kontrol edip tekrar deneyin.", "err");
      form.querySelector("#eposta").focus();
      return;
    }
    if (msg.length < 5) {
      setStatus("Lütfen mesajınızı kısaca yazın.", "err");
      form.querySelector("#mesaj").focus();
      return;
    }

    // Pending-backend state: do NOT claim delivery.
    // Decode double-encoding guard: build carefully
    var waUrl =
      "https://api.whatsapp.com/send/?phone=" +
      encodeURIComponent(WA_NUMBER) +
      "&text=" +
      encodeURIComponent(
        "Merhaba, web sitesi iletişim formundan yazıyorum.\n\nAd Soyad: " +
          name +
          "\nTelefon: " +
          phone +
          (email ? "\nE-posta: " + email : "") +
          (topic ? "\nKonu: " + topic : "") +
          "\nMesaj: " +
          msg
      );

    setStatus(
      "Form alındı — henüz otomatik gönderim bağlı değil. Dilerseniz mesajınızı WhatsApp üzerinden iletebilirsiniz.",
      "ok"
    );

    var waBtn = form.querySelector("[data-whatsapp-send]");
    if (waBtn) {
      waBtn.href = waUrl;
      waBtn.hidden = false;
      waBtn.focus();
    }
  });
})();
