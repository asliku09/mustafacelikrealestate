/* Shared interactions — nav + contact form (sends via e-mail service) */
(function () {
  "use strict";

  // Footer year
  document.querySelectorAll("[data-year]").forEach(function (el) {
    el.textContent = String(new Date().getFullYear());
  });

  // Contact form:
  // Sends to the address in data-email (from "iletişim bilgileri.txt")
  // via the FormSubmit AJAX endpoint — no custom backend needed.
  // NOTE: the mailbox owner must approve the one-time activation
  // e-mail that FormSubmit sends after the very first submission.
  var form = document.querySelector("[data-contact-form]");
  if (!form) return;

  var status = form.querySelector("[data-form-status]");
  var WA_NUMBER = form.getAttribute("data-whatsapp-number") || "905323881072";
  var EMAIL = form.getAttribute("data-email") || "";

  function setStatus(msg, kind) {
    if (!status) return;
    status.textContent = msg;
    status.classList.remove("ok", "err");
    if (kind) status.classList.add(kind);
  }

  function isEmail(v) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v);
  }

  function buildWaUrl(name, phone, email, topic, msg) {
    return (
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
      )
    );
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

    // WhatsApp alternative is always offered alongside e-mail sending.
    var waBtn = form.querySelector("[data-whatsapp-send]");
    if (waBtn) {
      waBtn.href = buildWaUrl(name, phone, email, topic, msg);
      waBtn.hidden = false;
    }

    if (!EMAIL) {
      setStatus("E-posta adresi tanımlı değil. WhatsApp ile iletebilirsiniz.", "err");
      if (waBtn) waBtn.focus();
      return;
    }

    var btn = form.querySelector('[type="submit"]');
    var orig = btn ? btn.textContent : "";
    if (btn) {
      btn.disabled = true;
      btn.textContent = "Gönderiliyor...";
    }
    setStatus("Mesajınız gönderiliyor...", "");

    fetch("https://formsubmit.co/ajax/" + encodeURIComponent(EMAIL), {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        "Ad Soyad": name,
        Telefon: phone,
        "E-posta": email || "-",
        Konu: topic || "-",
        Mesaj: msg,
        _subject: "Web sitesi iletişim formu: " + name,
        _template: "table",
        _captcha: "false"
      })
    })
      .then(function (res) {
        if (!res.ok) throw new Error("send-failed");
        return res.json();
      })
      .then(function () {
        setStatus("Mesajınız iletildi. En kısa sürede dönüş yapılacaktır.", "ok");
        form.reset();
        if (btn) {
          btn.disabled = false;
          btn.textContent = orig;
        }
      })
      .catch(function () {
        setStatus("E-posta gönderilemedi. Lütfen tekrar deneyin veya WhatsApp ile iletin.", "err");
        if (btn) {
          btn.disabled = false;
          btn.textContent = orig;
        }
        if (waBtn) waBtn.focus();
      });
  });
})();
