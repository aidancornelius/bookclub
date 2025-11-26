import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";

/**
 * Keyboard shortcuts help overlay
 * @component BookclubShortcutsHelp
 */
export default class BookclubShortcutsHelp extends Component {
  @service bookclubReading;

  shortcuts = [
    { key: "n / →", action: "Next chapter" },
    { key: "p / ←", action: "Previous chapter" },
    { key: "t", action: "Toggle contents" },
    { key: "d", action: "Jump to discussions" },
    { key: "s", action: "Toggle settings" },
    { key: "?", action: "Show shortcuts" },
    { key: "Esc", action: "Close panel" },
  ];

  get isVisible() {
    return this.bookclubReading.isShortcutsOpen;
  }

  @action
  close() {
    this.bookclubReading.toggleShortcuts();
  }

  @action
  handleOverlayClick(event) {
    if (event.target === event.currentTarget) {
      this.close();
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive no-nested-interactive }}
    <div
      class="bookclub-shortcuts-help
        {{if this.isVisible 'bookclub-shortcuts-help--visible'}}"
      role="button"
      {{on "click" this.handleOverlayClick}}
    >
      <div class="bookclub-shortcuts-help__panel">
        <h2 class="bookclub-shortcuts-help__title">Keyboard shortcuts</h2>
        <ul class="bookclub-shortcuts-help__list">
          {{#each this.shortcuts as |shortcut|}}
            <li class="bookclub-shortcuts-help__item">
              <span
                class="bookclub-shortcuts-help__action"
              >{{shortcut.action}}</span>
              <kbd class="bookclub-shortcuts-help__key">{{shortcut.key}}</kbd>
            </li>
          {{/each}}
        </ul>
        <div class="bookclub-shortcuts-help__close">
          <button type="button" {{on "click" this.close}}>Close</button>
        </div>
      </div>
    </div>
  </template>
}
