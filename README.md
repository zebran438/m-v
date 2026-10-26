# M&V Engineering: сайт фирмы и кабинет клиента

Сайт инженерной фирмы (кондиционеры, вентиляция, сантехника, Варшава) с регистрацией клиентов, личным кабинетом и панелью администратора. Всё запускается одной командой в Docker.

```
 Браузер ──►  Spring Boot (Java 21)  ──►  PostgreSQL 16
              • страницы сайта (HTML/CSS/JS)    • пользователи, заявки,
              • вход, роли, защита              работы, счета, сообщения
              • REST API  /api/...
              • хранит PDF-счета (volume)
 Adminer ───►  просмотр таблиц базы в браузере
```

## Что нужно установить
- **Docker Desktop** (на Windows включите WSL2). Больше ничего: Java и Maven ставить не нужно, сборка идёт внутри Docker.
- **Git**.

## Запуск
```
git clone <адрес репозитория>
cd mv-site-java
docker compose up --build
```
Первый раз сборка занимает 3–6 минут (скачиваются образы и библиотеки). Готово, когда в логе появится `Started SiteApplication`.

| Что | Адрес |
|---|---|
| Сайт и кабинет | http://localhost:8080 |
| Просмотр базы (Adminer) | http://localhost:8081 (система PostgreSQL, сервер `db`, пользователь `mv`, пароль `mv_dev_password`, база `mv`) |
| База для DBeaver и т.п. | `localhost:5432`, те же данные |

**Готовые аккаунты** (создаются при первом запуске, пока `DEMO_DATA=true`):

| Роль | E-mail | Пароль |
|---|---|---|
| Администратор | `admin@example.com` | `admin12345` |
| Клиент с примерными данными | `klient@example.com` | `klient12345` |

Это пароли для локальной работы. Для любого реального использования задайте свои в `.env` (см. ниже).

Остановить: `Ctrl+C`, затем `docker compose down`. Стереть все данные и начать с нуля: `docker compose down -v`.
Логи приложения: `docker compose logs -f app`.

## Что проверить (5 минут)
1. На главной странице отправьте сообщение из формы контакта.
2. «Panel klienta» → «Rejestracja»: создайте второго клиента. Он видит пустой кабинет.
3. Создайте от него заявку.
4. Выйдите, войдите как `klient@example.com`: заявки второго клиента вы не видите.
5. Войдите как администратор: в меню появились «Zgłoszenia klientów», «Klienci», «Wiadomości».
   - Смените статус заявки. Клиент увидит новый статус.
   - «Klienci»: выберите клиента, добавьте выполненную работу и фактуру с PDF-файлом. Клиент скачает PDF у себя, другой клиент его не получит.
6. Откройте Adminer и посмотрите те же данные в таблицах `users`, `service_requests`, `works`, `invoices`, `contact_messages`.

## Git: как отдать преподавателю или заказчику
```
git remote add origin https://github.com/ВАШ_ЛОГИН/mv-site-java.git
git push -u origin main
```
Получатель делает `git clone` и `docker compose up --build`, как в разделе «Запуск». Папка `.github/workflows/ci.yml` запускает автотесты на GitHub при каждом push (вкладка Actions).

Файл `.env` с вашими паролями в Git не попадает (он в `.gitignore`), в репозитории лежит только шаблон `.env.example`.

## Настройки (файл `.env`, шаблон: `.env.example`)
| Переменная | Что делает | По умолчанию |
|---|---|---|
| `DB_PASSWORD` | пароль базы. Менять до первого запуска; позже: `docker compose down -v` | `mv_dev_password` |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | администратор, создаётся при старте, если его ещё нет | `admin@example.com`, `admin12345` |
| `DEMO_DATA` | `true`: создать клиента `klient@example.com` с примерами | `true` |
| `SESSION_COOKIE_SECURE` | `true` только за HTTPS | `false` |

Если порт 5432 или 8080 занят, поменяйте левое число в `ports` в `docker-compose.yml`.

## Структура проекта
```
src/main/java/pl/mvengineering/site/
  domain/     таблицы как Java-классы (User, ServiceRequest, WorkItem, Invoice, ContactMessage)
  repo/       доступ к базе (Spring Data JPA)
  security/   вход, роли, CSRF (SecurityConfig)
  service/    логика: регистрация, кабинет, админ-операции, хранение PDF, стартовые данные
  web/        REST-контроллеры, проверка данных, обработка ошибок
src/main/resources/
  db/migration/V1__init.sql   схема базы (Flyway создаёт её при старте)
  static/                     сайт: index.html, css/style.css, js/app.js, polityka-prywatnosci.html
src/test/                     автотесты безопасности (JUnit, база H2 в памяти)
Dockerfile, docker-compose.yml
```

## API (все пути с `/api`)
| Метод и путь | Кто | Что делает |
|---|---|---|
| `POST /auth/register`, `POST /auth/login`, `POST /auth/logout`, `GET /auth/me` | все | регистрация, вход, выход, текущий пользователь |
| `PATCH /me`, `PUT /me/password` | клиент | свои данные, смена пароля |
| `GET /requests`, `POST /requests` | клиент | свои заявки, новая заявка |
| `GET /works`, `GET /invoices`, `GET /invoices/{id}/file` | клиент | свои работы и счета, скачать PDF (только свой) |
| `POST /contact` | все | сообщение из формы контакта |
| `GET /admin/requests`, `PATCH /admin/requests/{id}` | админ | все заявки, смена статуса |
| `GET /admin/clients`, `POST /admin/clients/{id}/works`, `POST /admin/clients/{id}/invoices` | админ | клиенты, добавить работу, добавить счёт (multipart с PDF) |
| `GET /admin/messages` | админ | сообщения из формы |

## Что сделано для безопасности
- Пароли хранятся только как хеш BCrypt. Сессия в cookie `HttpOnly` + `SameSite=Lax`, смена id сессии при входе.
- Защита от CSRF (токен в cookie `XSRF-TOKEN`, отправляется заголовком `X-XSRF-TOKEN`).
- Права проверяются на сервере: `/api/admin/**` только для роли ADMIN; id клиента берётся из сессии, а не из запроса, поэтому чужие данные получить нельзя (чужой счёт отвечает 404).
- Проверка входных данных (длины, e-mail, согласие с политикой), все значения на странице экранируются.
- PDF: только файлы, начинающиеся с `%PDF-`, до 5 МБ, хранятся вне папки сайта под случайными именами.

## Тесты
```
docker run --rm -v "${PWD}:/app" -w /app maven:3.9-eclipse-temurin-21 mvn -B test
```
(в PowerShell; в bash вместо `${PWD}` пишите `$(pwd)`). Тесты проверяют: гость не видит данные клиента, запрос без CSRF отклоняется, клиент видит только свои заявки и не может открыть админ-API и чужие счета, админ видит всё.

## Не реализовано (следующие шаги)
- Восстановление пароля по e-mail (нужен почтовый сервер, SMTP). Сейчас клиент пишет в фирму.
- Ограничение числа попыток входа.
- Уведомления администратору о новых заявках и сообщениях.
- Удаление аккаунта самим клиентом (сейчас по письму).

## Перед боевой публикацией
- Выложить за HTTPS (например, Caddy или nginx перед приложением), поставить `SESSION_COOKIE_SECURE=true`, свои пароли в `.env`, `DEMO_DATA=false`. Порты 5432 и 8081 наружу не открывать.
- Настроить резервные копии базы (`pg_dump`) и тома `invoices`.
- Заполнить поля `[...]` в `polityka-prywatnosci.html` и показать её юристу. Это шаблон.
- Заменить «do uzupełnienia» (телефон, e-mail), добавить фото и описания работ.
