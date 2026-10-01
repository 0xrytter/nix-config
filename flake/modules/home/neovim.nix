{ pkgs, ... }: {
  programs.nixvim = {
    enable = true;

    globals = {
      mapleader = " ";
      maplocalleader = " ";
      have_nerd_font = true;
    };

    opts = {
      number = true;
      mouse = "a";
      showmode = false;
      breakindent = true;
      undofile = true;
      ignorecase = true;
      smartcase = true;
      signcolumn = "yes";
      updatetime = 250;
      timeoutlen = 300;
      splitright = true;
      splitbelow = true;
      list = true;
      inccommand = "split";
      cursorline = true;
      scrolloff = 10;
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>x";
        action = ":bd<CR>";
        options.desc = "Close current buffer";
      }
      {
        mode = "n";
        key = "<leader>ya";
        action = ":%y+<CR>";
        options.desc = "Yank entire buffer to clipboard";
      }
      {
        mode = "n";
        key = "n";
        action = "nzz";
        options.desc = "Next search result centered";
      }
      {
        mode = "n";
        key = "N";
        action = "Nzz";
        options.desc = "Prev search result centered";
      }
      {
        mode = "n";
        key = "<leader>yp";
        action.__raw = "function() vim.fn.setreg('+', vim.fn.expand('%:p')) end";
        options.desc = "Yank absolute file path";
      }
      {
        mode = "n";
        key = "<leader>yr";
        action.__raw = "function() vim.fn.setreg('+', vim.fn.expand('%:.')) end";
        options.desc = "Yank relative file path";
      }
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
      }
      {
        mode = "n";
        key = "<leader>q";
        action.__raw = "vim.diagnostic.setloclist";
        options.desc = "Open diagnostic Quickfix list";
      }
      {
        mode = "t";
        key = "<Esc><Esc>";
        action = "<C-\\><C-n>";
        options.desc = "Exit terminal mode";
      }
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w><C-h>";
        options.desc = "Move focus left";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w><C-l>";
        options.desc = "Move focus right";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w><C-j>";
        options.desc = "Move focus down";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w><C-k>";
        options.desc = "Move focus up";
      }
    ];

    autoGroups = {
      "kickstart-highlight-yank" = {
        clear = true;
      };
    };

    autoCmd = [
      {
        event = [ "TextYankPost" ];
        desc = "Highlight when yanking text";
        group = "kickstart-highlight-yank";
        callback.__raw = "function() vim.hl.on_yank() end";
      }
    ];

    colorschemes.catppuccin = {
      enable = true;
    };

    plugins = {
      gitsigns = {
        enable = true;
        settings.signs = {
          add.text = "+";
          change.text = "~";
          delete.text = "_";
          topdelete.text = "‾";
          changedelete.text = "~";
        };
      };

      which-key = {
        enable = true;
        settings.spec = [
          {
            __unkeyed-1 = "<leader>c";
            group = "[C]ode";
            mode = [
              "n"
              "x"
            ];
          }
          {
            __unkeyed-1 = "<leader>d";
            group = "[D]ocument";
          }
          {
            __unkeyed-1 = "<leader>r";
            group = "[R]ename";
          }
          {
            __unkeyed-1 = "<leader>s";
            group = "[S]earch";
          }
          {
            __unkeyed-1 = "<leader>w";
            group = "[W]orkspace";
          }
          {
            __unkeyed-1 = "<leader>t";
            group = "[T]oggle";
          }
          {
            __unkeyed-1 = "<leader>h";
            group = "Git [H]unk";
            mode = [
              "n"
              "v"
            ];
          }
          {
            __unkeyed-1 = "<leader>g";
            group = "[G]it diffview";
          }
        ];
      };

      telescope = {
        enable = true;
        extensions.fzf-native.enable = true;
        extensions.ui-select.enable = true;
      };

      fidget.enable = true;

      lsp = {
        enable = true;
        capabilities = ''
          capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())
        '';
        servers = {
          elixirls.enable = true;
          ts_ls.enable = true;
          eslint.enable = true;
          bashls.enable = true;
          html.enable = true;
          pyright.enable = true;
          ruff.enable = true;
          gopls.enable = true;
          jsonls.enable = true;
          cssls.enable = true;
          dockerls.enable = true;
          docker_compose_language_service.enable = true;
          tailwindcss.enable = true;
          lua_ls = {
            enable = true;
            settings.Lua.completion.callSnippet = "Replace";
          };
          nixd.enable = true;
        };
      };

      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
          completion.completeopt = "menu,menuone,noinsert";
          mapping = {
            "<C-n>" = "cmp.mapping.select_next_item()";
            "<C-p>" = "cmp.mapping.select_prev_item()";
            "<C-b>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<C-y>" = "cmp.mapping.confirm({ select = true })";
            "<C-Space>" = "cmp.mapping.complete()";
          };
          sources = [
            {
              name = "lazydev";
              group_index = 0;
            }
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "path"; }
          ];
        };
      };

      luasnip.enable = true;
      nvim-autopairs.enable = true;
      cmp-nvim-lsp.enable = true;
      cmp-path.enable = true;
      cmp_luasnip.enable = true;

      conform-nvim = {
        enable = true;
        settings = {
          notify_on_error = false;
          format_on_save.__raw = ''
            function(bufnr)
              local disable_filetypes = { c = true, cpp = true, javascript = true, typescript = true }
              return {
                timeout_ms = 2000,
                lsp_format = disable_filetypes[vim.bo[bufnr].filetype] and "never" or "fallback",
              }
            end
          '';
          formatters_by_ft = {
            lua = [ "stylua" ];
            elixir = [ "lsp" ];
            go = [ "gofumpt" ];
            python = [ "ruff" ];
            nix = [ "nixfmt" ];
            sh = [ "shfmt" ];
            json = [ "prettierd" ];
            markdown = [ "prettierd" ];
            css = [ "prettierd" ];
          };
        };
      };

      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          highlight.additional_vim_regex_highlighting = [ "ruby" ];
          indent.enable = true;
          indent.disable = [ "ruby" ];
          auto_install = true;
          ensure_installed = [
            "bash"
            "c"
            "diff"
            "html"
            "lua"
            "luadoc"
            "markdown"
            "markdown_inline"
            "query"
            "vim"
            "vimdoc"
            "elixir"
            "heex"
            "go"
            "python"
            "css"
            "json"
            "nix"
            "tsx"
            "typescript"
            "javascript"
          ];
        };
      };

      todo-comments = {
        enable = true;
        settings.signs = false;
      };

      mini = {
        enable = true;
        modules = {
          ai = {
            n_lines = 500;
          };
          surround = { };
          statusline = {
            use_icons = true;
          };
        };
      };

      oil = {
        enable = true;
        settings = {
          default_file_explorer = true;
          delete_to_trash = true;
          skip_confirm_for_simple_edits = true;
          view_options = {
            show_hidden = true;
            natural_order = true;
            is_always_hidden.__raw = ''
              function(name, _)
                return name == '..' or name == '.git'
              end
            '';
          };
          win_options.wrap = true;
          lsp_file_methods = {
            enabled = true;
            timeout_ms = 1000;
            autosave_changes = false;
          };
        };
      };

      diffview.enable = true;

      neotest = {
        enable = true;
        adapters = {
          elixir.enable = true;
          python.enable = true;
          jest.enable = true;
        };
      };

      trouble = {
        enable = true;
        settings.modes.diagnostics.auto_open = false;
      };

      harpoon = {
        enable = true;
        enableTelescope = true;
      };

      web-devicons.enable = true;

      flash = {
        enable = true;
        settings = {
          jump.autojump = true;
          modes.char = {
            jump_labels = true;
            multi_line = false;
          };
        };
      };
    };

    extraPlugins = with pkgs.vimPlugins; [
      vim-sleuth
      lazydev-nvim
      luvit-meta
      nvim-ts-autotag
      nvim-web-devicons
      baleia-nvim
    ];

    # Formatter binaries for conform + the tools some LSPs shell out to.
    # LSP servers themselves are packaged by nixvim via the `servers` block.
    extraPackages = with pkgs; [
      gofumpt
      ruff
      nixfmt-rfc-style
      shfmt
    ];

    extraConfigLua = ''
      -- Deferred clipboard
      vim.schedule(function()
        vim.opt.clipboard = 'unnamedplus'
      end)

      vim.opt.autoread = true
      vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, { command = 'checktime' })

      local baleia = require('baleia').setup({ async = false })
      vim.api.nvim_create_autocmd('BufReadPost', {
        pattern = '/tmp/tmux-scrollback-*',
        callback = function()
          local buf = vim.api.nvim_get_current_buf()
          baleia.once(buf)
          vim.bo[buf].modified = false
        end,
      })

      vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
      vim.cmd.hi 'Comment gui=none'

      -- lazydev
      require('lazydev').setup {
        library = {
          { path = 'luvit-meta/library', words = { 'vim%.uv' } },
        },
      }

      -- Telescope
      require('telescope').setup {
        pickers = { find_files = { hidden = true } },
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags,     { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps,       { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files,    { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin,       { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string,   { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep,     { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics,   { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume,        { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles,      { desc = '[S]earch Recent Files' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
      vim.keymap.set('n', '<leader>sc', builtin.commands,      { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10, previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep { grep_open_files = true, prompt_title = 'Live Grep in Open Files' }
      end, { desc = '[S]earch [/] in Open Files' })
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })

      -- LSP keymaps on attach
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            vim.keymap.set(mode or 'n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end
          map('gd',        require('telescope.builtin').lsp_definitions,         '[G]oto [D]efinition')
          map('gr',        require('telescope.builtin').lsp_references,          '[G]oto [R]eferences')
          map('gI',        require('telescope.builtin').lsp_implementations,     '[G]oto [I]mplementation')
          map('<leader>D', require('telescope.builtin').lsp_type_definitions,    'Type [D]efinition')
          map('<leader>ds',require('telescope.builtin').lsp_document_symbols,    '[D]ocument [S]ymbols')
          map('<leader>ws',require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
          map('<leader>rn',vim.lsp.buf.rename,                                   '[R]e[n]ame')
          map('<leader>ca',vim.lsp.buf.code_action,                              '[C]ode [A]ction', { 'n', 'x' })
          map('gD',        vim.lsp.buf.declaration,                              '[G]oto [D]eclaration')

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local hl = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf, group = hl, callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf, group = hl, callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(ev)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = ev.buf }
              end,
            })
          end

          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- conform format keymap
      vim.keymap.set({ 'n', 'v' }, '<leader>f', function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end, { desc = '[F]ormat buffer' })

      -- nvim-ts-autotag
      require('nvim-ts-autotag').setup {
        filetypes = {
          'html', 'javascript', 'typescript', 'javascriptreact',
          'typescriptreact', 'svelte', 'vue',
        },
        aliases = { heex = 'html', elixir = 'html' },
      }

      -- oil keymap
      vim.keymap.set('n', '<leader>o', '<cmd>Oil<cr>', { desc = 'Open oil file explorer' })

      -- harpoon
      local harpoon = require('harpoon')
      harpoon:setup()
      vim.keymap.set('n', '<leader>a', function() harpoon:list():add() end,                       { desc = 'Harpoon add file' })
      vim.keymap.set('n', '<C-e>',     function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = 'Harpoon menu' })
      vim.keymap.set('n', '<C-1>',     function() harpoon:list():select(1) end)
      vim.keymap.set('n', '<C-2>',     function() harpoon:list():select(2) end)
      vim.keymap.set('n', '<C-3>',     function() harpoon:list():select(3) end)
      vim.keymap.set('n', '<C-4>',     function() harpoon:list():select(4) end)

      -- neotest
      vim.keymap.set('n', '<leader>tt', function() require('neotest').run.run() end,                   { desc = '[T]est nearest' })
      vim.keymap.set('n', '<leader>tf', function() require('neotest').run.run(vim.fn.expand('%')) end,  { desc = '[T]est file' })
      vim.keymap.set('n', '<leader>ts', function() require('neotest').summary.toggle() end,            { desc = '[T]est summary' })
      vim.keymap.set('n', '<leader>to', function() require('neotest').output_panel.toggle() end,       { desc = '[T]est output' })
      vim.keymap.set('n', '<leader>tS', function() require('neotest').run.stop() end,                  { desc = '[T]est stop' })

      -- trouble
      vim.keymap.set('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>',              { desc = 'Trouble diagnostics' })
      vim.keymap.set('n', '<leader>xb', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', { desc = 'Trouble buffer diagnostics' })
      vim.keymap.set('n', '<leader>xl', '<cmd>Trouble loclist toggle<cr>',                  { desc = 'Trouble location list' })
      vim.keymap.set('n', '<leader>xq', '<cmd>Trouble qflist toggle<cr>',                   { desc = 'Trouble quickfix' })

      -- flash keymaps
      vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end,              { desc = 'Flash' })
      vim.keymap.set('n',               'S', function() require('flash').treesitter() end,         { desc = 'Flash Treesitter' })
      vim.keymap.set('o',               'r', function() require('flash').remote() end,             { desc = 'Remote Flash' })
      vim.keymap.set({ 'o', 'x' },      'R', function() require('flash').treesitter_search() end, { desc = 'Treesitter Search' })
      vim.keymap.set('c',           '<c-s>', function() require('flash').toggle() end,             { desc = 'Toggle Flash Search' })

      -- diffview: the review gate before any agent diff is committed
      vim.keymap.set('n', '<leader>gd', '<cmd>DiffviewOpen<cr>',          { desc = '[G]it [D]iff working tree' })
      vim.keymap.set('n', '<leader>gl', '<cmd>DiffviewOpen HEAD~1<cr>',   { desc = '[G]it diff [L]ast commit' })
      vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', { desc = '[G]it file [H]istory' })
      vim.keymap.set('n', '<leader>gH', '<cmd>DiffviewFileHistory<cr>',   { desc = '[G]it branch [H]istory' })
      vim.keymap.set('n', '<leader>gq', '<cmd>DiffviewClose<cr>',         { desc = '[G]it diffview [Q]uit' })
      -- Review gate: each unpushed commit opens as one plain `git show` buffer,
      -- so <leader>ce/cq work on it like any file, and <leader>gs stamps it.
      -- The pre-push hook refuses unstamped commits (see git-stamp in common.nix).
      local function review_commit(sha)
        local name = 'review://' .. sha
        if vim.fn.bufexists(name) == 1 then return vim.cmd.buffer(name) end
        local res = vim.system({ 'git', 'show', '--stat', '--patch', sha }, { text = true }):wait()
        if res.code ~= 0 then
          return vim.notify('git show: ' .. res.stderr, vim.log.levels.ERROR)
        end
        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(res.stdout, '\n'))
        vim.api.nvim_buf_set_name(buf, name)
        vim.bo[buf].filetype = 'git'
        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = 'wipe'
        vim.b[buf].review_sha = sha
        vim.api.nvim_set_current_buf(buf)
      end
      vim.keymap.set('n', '<leader>gr', function()
        local actions, state = require('telescope.actions'), require('telescope.actions.state')
        builtin.git_commits {
          prompt_title = 'Unpushed commits',
          git_command = { 'git', 'log', '--pretty=oneline', '--abbrev-commit', '@{upstream}..HEAD' },
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              local entry = state.get_selected_entry()
              actions.close(prompt_bufnr)
              if not entry then
                return vim.notify('review: no unpushed commit selected', vim.log.levels.WARN)
              end
              review_commit(entry.value)
            end)
            return true
          end,
        }
      end, { desc = '[G]it [R]eview unpushed commits' })
      vim.keymap.set('n', '<leader>gs', function()
        local sha = vim.b.review_sha
        if not sha then
          return vim.notify('stamp: open a commit with <leader>gr first', vim.log.levels.WARN)
        end
        vim.ui.input({ prompt = ('Stamp %s, what does it do? '):format(sha) }, function(summary)
          if not summary or summary == "" then return end
          local res = vim.system({ 'git', 'stamp', sha, summary }, { text = true }):wait()
          if res.code ~= 0 then
            return vim.notify('stamp failed: ' .. res.stderr, vim.log.levels.ERROR)
          end
          vim.notify(('stamped %s'):format(sha))
        end)
      end, { desc = '[G]it [S]tamp commit as reviewed' })

      -- Ask DeepSeek about the visual selection, with follow-ups in the same
      -- float. A raw Messages call to Hyper with thinking disabled answers in
      -- ~1s; going through the Claude Code harness took 3-4s. The key comes
      -- from `sec` per request and reaches curl on stdin, never argv.
      local chat = { messages = {} }

      local function show(lines)
        if not (chat.buf and vim.api.nvim_buf_is_valid(chat.buf)) then
          chat.buf = vim.api.nvim_create_buf(false, true)
          vim.bo[chat.buf].filetype = 'markdown'
          vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = chat.buf, desc = 'Close chat' })
          vim.keymap.set('n', '<CR>', function()
            vim.ui.input({ prompt = 'Follow-up: ' }, function(q)
              if q and q ~= "" then chat.ask(q) end
            end)
          end, { buffer = chat.buf, desc = 'Ask a follow-up' })
        end
        local empty = vim.api.nvim_buf_line_count(chat.buf) == 1 and vim.api.nvim_buf_get_lines(chat.buf, 0, 1, false)[1] == ""
        vim.api.nvim_buf_set_lines(chat.buf, empty and 0 or -1, -1, false, lines)
        if vim.fn.bufwinid(chat.buf) == -1 then
          local width, height = math.floor(vim.o.columns * 0.7), math.floor(vim.o.lines * 0.6)
          local win = vim.api.nvim_open_win(chat.buf, true, {
            relative = 'editor', style = 'minimal', border = 'rounded', title = ' ask (<CR> follow-up, q close) ',
            width = width, height = height,
            row = math.floor((vim.o.lines - height) / 2), col = math.floor((vim.o.columns - width) / 2),
          })
          vim.wo[win].wrap = true
        end
        vim.api.nvim_win_set_cursor(vim.fn.bufwinid(chat.buf), { vim.api.nvim_buf_line_count(chat.buf), 0 })
      end

      local function send()
        local key = vim.system({ 'sec', 'hyper-api-key' }, { text = true }):wait()
        if key.code ~= 0 then
          table.remove(chat.messages)
          return vim.notify('sec: ' .. key.stderr, vim.log.levels.ERROR)
        end
        local body = vim.json.encode({
          model = 'deepseek-v4.1-flash', max_tokens = 1024, thinking = { type = 'disabled' },
          system = 'You explain code to an experienced developer who is learning this language. Be terse.',
          messages = chat.messages,
        })
        -- curl config: inside double quotes only \ and " need escaping.
        local config = ('header = "x-api-key: %s"\ndata-binary = "%s"\n'):format(vim.trim(key.stdout), (body:gsub('[\\"]', '\\%0')))
        vim.notify('ask: waiting…')
        vim.system(
          { 'curl', '-sS', '-K', '-', '-H', 'anthropic-version: 2023-06-01', '-H', 'content-type: application/json', 'https://hyper.charm.land/v1/messages' },
          { stdin = config, text = true },
          vim.schedule_wrap(function(res)
            local ok, resp = pcall(vim.json.decode, res.stdout)
            local text = ok and type(resp.content) == 'table' and vim.iter(resp.content):find(function(c) return c.type == 'text' end)
            if res.code ~= 0 or not text then
              table.remove(chat.messages)
              return vim.notify('ask failed: ' .. (res.stderr ~= "" and res.stderr or res.stdout), vim.log.levels.ERROR)
            end
            table.insert(chat.messages, { role = 'assistant', content = text.text })
            show(vim.list_extend(vim.split(text.text, '\n'), { "" }))
          end)
        )
      end

      function chat.ask(question)
        table.insert(chat.messages, { role = 'user', content = question })
        show({ '## ' .. question, "" })
        send()
      end

      -- Starts a fresh chat: the selection goes into the first message only.
      local function ask_about(lines, question)
        chat.messages = {}
        if chat.buf and vim.api.nvim_buf_is_valid(chat.buf) then vim.api.nvim_buf_set_lines(chat.buf, 0, -1, false, {}) end
        local code = ('From %s (%s):\n```\n%s\n```\n\n'):format(vim.fn.expand('%:.'), vim.bo.filetype, table.concat(lines, '\n'))
        table.insert(chat.messages, { role = 'user', content = code .. question })
        show({ '## ' .. question, "" })
        send()
      end

      local function take_selection()
        local lines = vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = vim.fn.mode() })
        vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
        return lines
      end
      vim.keymap.set('x', '<leader>ce', function() ask_about(take_selection(), 'Explain this code.') end, { desc = '[C]ode [E]xplain selection' })
      vim.keymap.set('x', '<leader>cq', function()
        local lines = take_selection()
        vim.ui.input({ prompt = 'Ask about selection: ' }, function(q)
          if q and q ~= "" then ask_about(lines, q) end
        end)
      end, { desc = '[C]ode [Q]uestion about selection' })
      vim.keymap.set('n', '<leader>cc', function() show({}) end, { desc = '[C]ode reopen [C]hat' })

      -- mini statusline section override
      require('mini.statusline').section_location = function() return '%2l:%-2v' end
    '';
  };
}
