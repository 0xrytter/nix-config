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
      { mode = "n"; key = "<leader>x"; action = ":bd<CR>"; options.desc = "Close current buffer"; }
      { mode = "n"; key = "<Esc>"; action = "<cmd>nohlsearch<CR>"; }
      { mode = "n"; key = "<leader>q"; action.__raw = "vim.diagnostic.setloclist"; options.desc = "Open diagnostic Quickfix list"; }
      { mode = "t"; key = "<Esc><Esc>"; action = "<C-\\><C-n>"; options.desc = "Exit terminal mode"; }
      { mode = "n"; key = "<C-h>"; action = "<C-w><C-h>"; options.desc = "Move focus left"; }
      { mode = "n"; key = "<C-l>"; action = "<C-w><C-l>"; options.desc = "Move focus right"; }
      { mode = "n"; key = "<C-j>"; action = "<C-w><C-j>"; options.desc = "Move focus down"; }
      { mode = "n"; key = "<C-k>"; action = "<C-w><C-k>"; options.desc = "Move focus up"; }
    ];

    autoGroups = {
      "kickstart-highlight-yank" = { clear = true; };
    };

    autoCmd = [
      {
        event = [ "TextYankPost" ];
        desc = "Highlight when yanking text";
        group = "kickstart-highlight-yank";
        callback.__raw = "function() vim.highlight.on_yank() end";
      }
    ];

    colorschemes.gruvbox = {
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
          { __unkeyed-1 = "<leader>c"; group = "[C]ode"; mode = [ "n" "x" ]; }
          { __unkeyed-1 = "<leader>d"; group = "[D]ocument"; }
          { __unkeyed-1 = "<leader>r"; group = "[R]ename"; }
          { __unkeyed-1 = "<leader>s"; group = "[S]earch"; }
          { __unkeyed-1 = "<leader>w"; group = "[W]orkspace"; }
          { __unkeyed-1 = "<leader>t"; group = "[T]oggle"; }
          { __unkeyed-1 = "<leader>h"; group = "Git [H]unk"; mode = [ "n" "v" ]; }
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
          svelte.enable = true;
          elixirls.enable = true;
          ts_ls.enable = true;
          eslint.enable = true;
          bashls.enable = true;
          html.enable = true;
          pyright.enable = true;
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
            { name = "lazydev"; group_index = 0; }
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "path"; }
          ];
        };
      };

      luasnip.enable = true;
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
            heex = [ "lsp" ];
            cs = [ "csharpier" ];
            javascript = [ "prettierd" ];
            typescript = [ "prettierd" ];
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
            "bash" "c" "diff" "html" "lua" "luadoc" "markdown" "markdown_inline"
            "query" "vim" "vimdoc" "elixir" "heex" "svelte" "c_sharp"
            "tsx" "typescript" "javascript"
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
          ai = { n_lines = 500; };
          surround = { };
          statusline = { use_icons = true; };
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

      git-conflict.enable = true;

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
    ];

    extraConfigLua = ''
      -- Deferred clipboard
      vim.schedule(function()
        vim.opt.clipboard = 'unnamedplus'
      end)

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
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
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

          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
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

      -- mini statusline section override
      require('mini.statusline').section_location = function() return '%2l:%-2v' end
    '';
  };
}
