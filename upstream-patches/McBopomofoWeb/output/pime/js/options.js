window.onload = () => {
  const defaultSettings = {
    input_mode: "use_mcbopomofo",
    candidate_font_size: 16,
    layout: "standard",
    select_phrase: "before_cursor",
    candidate_keys: "123456789",
    candidate_keys_count: 9,
    esc_key_clear_entire_buffer: false,
    moving_cursor_option: 0,
    shift_key_toggle_alphabet_mode: true,
    half_width_punctuation: false,
    chinese_conversion: false,
    move_cursor: false,
    letter_mode: "upper",
    ctrl_enter_option: 0,
    by_default_deactivated: false,
    beep_on_error: true,
    repeated_punctuation_choose_candidate: false,
    bopomofo_font_annotation_support_enabled: false,
  };

  const annotationFontFamilies = [
    "BpmfZihiKaiStd",
    "BpmfZihiSans",
    "BpmfZihiSerif",
    "BpmfSpecial",
  ];

  const annotationSampleText =
    "\u6CE8\u97F3\u6E2C\u8A66 \u3105\u3106\u3107\u3108 \u7834\u97F3\u5B57";

  let settings = { ...defaultSettings };
  let annotationFontAvailability = {
    available: false,
    required: annotationFontFamilies.slice(),
    found: [],
  };

  function saveSettings(currentSettings) {
    const xhttp = new XMLHttpRequest();
    xhttp.open("POST", "/config");
    xhttp.setRequestHeader("Content-Type", "application/json; charset=UTF-8");
    xhttp.send(JSON.stringify(currentSettings));
  }

  function openUserDataFolder() {
    const xhttp = new XMLHttpRequest();
    xhttp.open("GET", "/open_user_data_folder");
    xhttp.send();
  }

  function detectAnnotationFonts() {
    const found = [];

    for (const family of annotationFontFamilies) {
      try {
        if (document.fonts.check(`16px "${family}"`, annotationSampleText)) {
          found.push(family);
        }
      } catch {
        // Ignore and leave this family undetected.
      }
    }

    annotationFontAvailability = {
      available: found.length === annotationFontFamilies.length,
      required: annotationFontFamilies.slice(),
      found: found,
    };
  }

  function loadFontAvailability(callback) {
    const runDetect = () => {
      detectAnnotationFonts();
      callback();
    };

    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(runDetect).catch(runDetect);
      return;
    }

    runDetect();
  }

  function updateAnnotationOptionVisibility() {
    const container = document.getElementById(
      "bopomofo_font_annotation_support_container"
    );
    const checkbox = document.getElementById(
      "bopomofo_font_annotation_support_enabled"
    );
    const note = document.getElementById(
      "bopomofo_font_annotation_support_note"
    );

    if (!annotationFontAvailability.available) {
      container.style.display = "none";
      checkbox.checked = false;
      if (settings.bopomofo_font_annotation_support_enabled) {
        settings.bopomofo_font_annotation_support_enabled = false;
        saveSettings(settings);
      }
      return;
    }

    container.style.display = "";
    checkbox.checked = !!settings.bopomofo_font_annotation_support_enabled;
    note.textContent =
      "\u5DF2\u5075\u6E2C\u5230\u6CE8\u97F3\u5B57\u578B\uFF0C\u53EF\u555F\u7528\u7834\u97F3\u5B57\u6A19\u8A18\u6A21\u5F0F\u3002";
  }

  function selectOptionByValue(selectId, value) {
    const select = document.getElementById(selectId);
    const options = select.getElementsByTagName("option");
    for (const option of options) {
      if (option.value == value) {
        option.selected = "selected";
        break;
      }
    }
  }

  function applySettings(currentSettings) {
    document.getElementById("use_plainbopomofo").checked =
      currentSettings.input_mode === "use_plainbopomofo";
    document.getElementById("use_mcbopomofo").checked =
      currentSettings.input_mode !== "use_plainbopomofo";

    if (currentSettings.candidate_font_size === undefined) {
      currentSettings.candidate_font_size = 16;
    }

    selectOptionByValue("font_size", currentSettings.candidate_font_size);
    selectOptionByValue("layout", currentSettings.layout);
    selectOptionByValue("keys", currentSettings.candidate_keys);
    selectOptionByValue("keys_count", currentSettings.candidate_keys_count);
    selectOptionByValue(
      "moving_cursor_option",
      currentSettings.moving_cursor_option
    );
    selectOptionByValue("ctrl_enter_option", currentSettings.ctrl_enter_option);

    document.getElementById("before_cursor").checked =
      currentSettings.select_phrase === "before_cursor";
    document.getElementById("after_cursor").checked =
      currentSettings.select_phrase === "after_cursor";

    document.getElementById("esc_key").checked =
      !!currentSettings.esc_key_clear_entire_buffer;
    document.getElementById("shift_key").checked =
      currentSettings.shift_key_toggle_alphabet_mode === undefined
        ? true
        : !!currentSettings.shift_key_toggle_alphabet_mode;
    document.getElementById("move_cursor").checked = !!currentSettings.move_cursor;
    document.getElementById("repeated_punctuation_choose_candidate").checked =
      !!currentSettings.repeated_punctuation_choose_candidate;
    document.getElementById("by_default_deactivated").checked =
      !!currentSettings.by_default_deactivated;
    document.getElementById("beep_on_error").checked =
      currentSettings.beep_on_error === undefined
        ? true
        : !!currentSettings.beep_on_error;

    document.getElementById("uppercase_letters").checked =
      currentSettings.letter_mode !== "lower";
    document.getElementById("lowercase_letters").checked =
      currentSettings.letter_mode === "lower";

    updateAnnotationOptionVisibility();
  }

  (function loadConfig() {
    const xhttp = new XMLHttpRequest();
    xhttp.onload = function () {
      try {
        const loaded = JSON.parse(this.responseText);
        settings = loaded === undefined ? { ...defaultSettings } : loaded;
      } catch {
        settings = { ...defaultSettings };
      }

      settings = { ...defaultSettings, ...settings };
      loadFontAvailability(() => {
        applySettings(settings);
      });
    };
    xhttp.onerror = function () {
      settings = { ...defaultSettings };
      loadFontAvailability(() => {
        applySettings(settings);
      });
    };
    xhttp.open("GET", "/config");
    xhttp.send("");
  })();

  document.getElementById("use_mcbopomofo").onchange = () => {
    settings.input_mode = "use_mcbopomofo";
    saveSettings(settings);
  };

  document.getElementById("use_plainbopomofo").onchange = () => {
    settings.input_mode = "use_plainbopomofo";
    saveSettings(settings);
  };

  document.getElementById("font_size").onchange = () => {
    settings.candidate_font_size = +document.getElementById("font_size").value;
    saveSettings(settings);
  };

  document.getElementById("layout").onchange = () => {
    settings.layout = document.getElementById("layout").value;
    saveSettings(settings);
  };

  document.getElementById("keys").onchange = () => {
    settings.candidate_keys = document.getElementById("keys").value;
    saveSettings(settings);
  };

  document.getElementById("keys_count").onchange = () => {
    settings.candidate_keys_count = +document.getElementById("keys_count").value;
    saveSettings(settings);
  };

  document.getElementById("moving_cursor_option").onchange = () => {
    settings.moving_cursor_option = +document.getElementById(
      "moving_cursor_option"
    ).value;
    saveSettings(settings);
  };

  document.getElementById("before_cursor").onchange = () => {
    settings.select_phrase = "before_cursor";
    saveSettings(settings);
  };

  document.getElementById("after_cursor").onchange = () => {
    settings.select_phrase = "after_cursor";
    saveSettings(settings);
  };

  document.getElementById("esc_key").onchange = () => {
    settings.esc_key_clear_entire_buffer =
      document.getElementById("esc_key").checked;
    saveSettings(settings);
  };

  document.getElementById("shift_key").onchange = () => {
    settings.shift_key_toggle_alphabet_mode =
      document.getElementById("shift_key").checked;
    saveSettings(settings);
  };

  document.getElementById("uppercase_letters").onchange = () => {
    settings.letter_mode = "upper";
    saveSettings(settings);
  };

  document.getElementById("lowercase_letters").onchange = () => {
    settings.letter_mode = "lower";
    saveSettings(settings);
  };

  document.getElementById("move_cursor").onchange = () => {
    settings.move_cursor = document.getElementById("move_cursor").checked;
    saveSettings(settings);
  };

  document.getElementById("ctrl_enter_option").onchange = () => {
    settings.ctrl_enter_option = +document.getElementById(
      "ctrl_enter_option"
    ).value;
    saveSettings(settings);
  };

  document.getElementById("by_default_deactivated").onchange = () => {
    settings.by_default_deactivated =
      document.getElementById("by_default_deactivated").checked;
    saveSettings(settings);
  };

  document.getElementById("beep_on_error").onchange = () => {
    settings.beep_on_error = document.getElementById("beep_on_error").checked;
    saveSettings(settings);
  };

  document.getElementById("repeated_punctuation_choose_candidate").onchange =
    () => {
      settings.repeated_punctuation_choose_candidate = document.getElementById(
        "repeated_punctuation_choose_candidate"
      ).checked;
      saveSettings(settings);
    };

  document.getElementById(
    "bopomofo_font_annotation_support_enabled"
  ).onchange = () => {
    settings.bopomofo_font_annotation_support_enabled = document.getElementById(
      "bopomofo_font_annotation_support_enabled"
    ).checked;
    saveSettings(settings);
  };

  document.getElementById("open_data_folder").onclick = () => {
    openUserDataFolder();
    return false;
  };
};
