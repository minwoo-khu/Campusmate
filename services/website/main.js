const screens = [
  "./assets/images/01_home.png",
  "./assets/images/02_todo.png",
  "./assets/images/03_calendar.png",
  "./assets/images/04_timetable.png",
  "./assets/images/05_courses.png",
];

const screenImage = document.getElementById("screenImage");
const dotsWrap = document.getElementById("screenDots");
const prevBtn = document.getElementById("prevBtn");
const nextBtn = document.getElementById("nextBtn");
let index = 0;
let autoTimer = null;

function renderDots() {
  if (!dotsWrap) return;
  dotsWrap.innerHTML = "";
  screens.forEach((_, i) => {
    const dot = document.createElement("button");
    dot.className = "screen-dot" + (i === index ? " active" : "");
    dot.type = "button";
    dot.ariaLabel = `screen ${i + 1}`;
    dot.addEventListener("click", () => {
      index = i;
      updateScreen();
      restartAutoPlay();
    });
    dotsWrap.appendChild(dot);
  });
}

function updateScreen() {
  if (!screenImage) return;
  screenImage.src = screens[index];
  renderDots();
}

function step(delta) {
  index = (index + delta + screens.length) % screens.length;
  updateScreen();
}

function restartAutoPlay() {
  if (autoTimer) clearInterval(autoTimer);
  autoTimer = setInterval(() => step(1), 3200);
}

if (prevBtn) {
  prevBtn.addEventListener("click", () => {
    step(-1);
    restartAutoPlay();
  });
}

if (nextBtn) {
  nextBtn.addEventListener("click", () => {
    step(1);
    restartAutoPlay();
  });
}

const revealItems = document.querySelectorAll(".reveal");
const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("show");
        observer.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.16 }
);

revealItems.forEach((item) => observer.observe(item));

updateScreen();
restartAutoPlay();
