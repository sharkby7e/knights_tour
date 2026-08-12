# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "game/square", to: "game/square.mjs"
pin "game/move_finder", to: "game/move_finder.mjs"
pin "game/knight_tour_game", to: "game/knight_tour_game.mjs"
pin "game/board_view", to: "game/board_view.mjs"
