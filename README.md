# pesito · iOS app

SwiftUI приложение для заёмщиков pesito (Mexico SOFOM ENR Bonum). Говорит с тем же бэком pesito-api, что и веб `/cuenta` — `https://gaz.eg.je`.

## Сборка

Нужно: macOS + Xcode 15+ и [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone git@github.com:egegje/pesito-ios.git
cd pesito-ios
xcodegen generate
open pesito.xcodeproj
```

В Xcode:

1. Выбрать Target `pesito` → Signing & Capabilities → Team = свой Apple Developer.
   (После каждого `xcodegen generate` Team сбрасывается — придётся выбрать заново.)
2. Выбрать симулятор (iPhone 15 Pro) или подключённое устройство.
3. ⌘R запустить.

## Что внутри

```
Sources/
├── pesitoApp.swift                          @main entry, @StateObject AppStore
├── Models/AppStore.swift                    Состояние приложения (loading/login/otp/dashboard)
├── Network/PesitoAPI.swift                  URLSession actor: auth, me, loans, apply, pay
├── Theme/Theme.swift                        Цвета, шрифты, кнопки, карточки — pesito cream
├── Views/RootView.swift                     Маршрутизация по фазам
├── Views/Onboarding/                        Splash + 3 экрана онбординга (первый запуск)
├── Views/Auth/                              Phone entry + OTP с авто-подстановкой из SMS
├── Views/Apply/ApplyView.swift              Мастер заявки на займ (8 шагов)
├── Views/Main/MainTabsView.swift            Нижняя таб-панель (Inicio / Solicitar / Historial / Cuenta)
├── Views/Main/DashboardView.swift           Активный займ + LoanCard + EmptyLoansView
├── Views/Main/PaySheet.swift                Полу-шит выбора метода (CARD / OXXO / SPEI)
├── Views/Main/HistoryView.swift             История займов и платежей
└── Views/Main/AccountView.swift             Профиль, язык, легал, выход, удаление аккаунта
Resources/
└── Info.plist                               Bundle config + ATS (только gaz.eg.je) + camera/face-id permissions
project.yml                                  XcodeGen config — генерирует .xcodeproj
```

## Дизайн-система

Цвета и шрифты подняты из `/opt/gaz.eg.je/public/styles.css` (web cream/editorial), один источник правды — `Sources/Theme/Theme.swift`. **Никогда не вкладывай hex/rgb прямо во view** — добавляй токен в Theme.swift.

- `PesitoColor.bg` — кремовый фон
- `PesitoColor.ink` — тёмный тёплый текст
- `PesitoColor.brand` — терракотовый акцент
- `PesitoSpace.{xxs..xxxl}` — 4pt шкала отступов
- `Font.pesitoTitleL`, `.pesitoBodyM` — типографика (Antonio display + Manrope body)
- `PesitoPrimaryButton`, `PesitoSecondaryButton`, `.pesitoCard()`, `.pesitoField()` — переиспользуемые стили

## Тестовый сценарий

1. Запуск → Splash → Onboarding (только первый раз) → Login
2. Ввести телефон `+525500000044` → Enviar código
3. Код в sandbox — `000000` → Entrar
4. Дашборд: видишь активные займы, либо EmptyLoansView
5. Таб «Solicitar» → мастер из 8 шагов: сумма/срок → identity → address → income → bank → docs → otp → review → submit
6. Tab «Historial» → закрытые займы и оплаченные платежи
7. Tab «Cuenta» → профиль, язык, выход

## API

Все эндпоинты на `https://gaz.eg.je`, сессия по cookie (бэк ставит `pesito_session`):

| Метод | Путь | Что |
| --- | --- | --- |
| POST | `/api/v1/auth/login/start` | Запросить SMS-код |
| POST | `/api/v1/auth/login/verify` | Подтвердить код |
| POST | `/api/v1/auth/logout` | Выход |
| GET  | `/api/v1/me` | Профиль |
| GET  | `/api/v1/me/loans` | Список займов |
| POST | `/api/v1/me/loans/:id/pay` | Оплата (с method=CARD/OXXO/SPEI) |
| POST | `/api/v1/apply/start` | Начать заявку |
| POST | `/api/v1/apply/:id/data` | Сохранить шаг |
| POST | `/api/v1/apply/:id/otp/send` | OTP для apply-flow |
| POST | `/api/v1/apply/:id/otp/verify` | Подтвердить OTP |
| POST | `/api/v1/apply/:id/submit` | Финализировать → scoring |

Заголовок `x-tenant: mx` шлётся всегда (мульти-арендатор бэк по странам).

## TODO (V0.5+)

- Mifiel signing (in-app SFSafariViewController + deep-link callback `pesito://signed`)
- Камера для INE/селфи (сейчас плейсхолдер на шаге docs)
- APNs push (3 дня до платежа + день в день)
- Conekta hosted checkout для CARD (сейчас просто шлём method, без секьюрного фронта)
- Face ID для входа без OTP
- Шрифты Antonio + Manrope как .ttf-файлы в Resources/Fonts (сейчас fallback на SF Pro)
