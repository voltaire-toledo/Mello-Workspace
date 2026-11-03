// Mello-Workspace Showcase & Interactive Engine
// Provides simulated micro-videos / animations of interactions & parallax background shapes

document.addEventListener('DOMContentLoaded', () => {
  // 1. Subtle scroll-linked geometric background movement
  const shapes = document.querySelectorAll('.shape');
  window.addEventListener('scroll', () => {
    const scrollY = window.scrollY;
    shapes.forEach((shape, index) => {
      const speed = (index + 1) * 0.08;
      const rotation = (scrollY * 0.04 * (index % 2 === 0 ? 1 : -1));
      shape.style.transform = `translateY(${scrollY * speed}px) rotate(${rotation}deg)`;
    });
  }, { passive: true });

  // 2. Showcase tab switching
  const tabButtons = document.querySelectorAll('.tab-btn');
  const panels = document.querySelectorAll('.showcase-panel');

  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.getAttribute('data-target');
      
      tabButtons.forEach(b => b.classList.remove('active'));
      panels.forEach(p => p.classList.remove('active'));

      btn.classList.add('active');
      const targetPanel = document.getElementById(targetId);
      if (targetPanel) {
        targetPanel.classList.add('active');
      }
    });
  });

  // 3. Interactive Simulations

  // A. Snapping Simulation
  const btnTriggerSnap = document.getElementById('btnTriggerSnap');
  const winLeft = document.querySelector('.win-left');
  const winRight = document.querySelector('.win-right');

  let snapState = 0;
  if (btnTriggerSnap && winLeft && winRight) {
    btnTriggerSnap.addEventListener('click', () => {
      snapState = (snapState + 1) % 3;
      if (snapState === 0) {
        // 50/50 split
        winLeft.style.flex = '1';
        winRight.style.display = 'flex';
        winRight.style.flex = '1';
      } else if (snapState === 1) {
        // Left 70%, Right 30%
        winLeft.style.flex = '2';
        winRight.style.flex = '1';
      } else if (snapState === 2) {
        // Maximized Focus (Left full, right hidden)
        winLeft.style.flex = '1';
        winRight.style.display = 'none';
      }
    });
  }

  // B. QuickNote Toggle Simulation
  const btnToggleNotepad = document.getElementById('btnToggleNotepad');
  const notepad = document.querySelector('.sim-notepad');
  let notepadVisible = true;

  if (btnToggleNotepad && notepad) {
    btnToggleNotepad.addEventListener('click', () => {
      notepadVisible = !notepadVisible;
      if (notepadVisible) {
        notepad.style.opacity = '1';
        notepad.style.transform = 'translateY(0) scale(1)';
        btnToggleNotepad.textContent = 'Simulate Esc (Dismiss)';
      } else {
        notepad.style.opacity = '0.15';
        notepad.style.transform = 'translateY(10px) scale(0.97)';
        btnToggleNotepad.textContent = 'Simulate Win+N (Summon)';
      }
      notepad.style.transition = 'all 0.2s cubic-bezier(0.16, 1, 0.3, 1)';
    });
  }

  // C. SoundSwap Simulation
  const btnTriggerSoundSwap = document.getElementById('btnTriggerSoundSwap');
  const devHeadphones = document.getElementById('devHeadphones');
  const devSpeakers = document.getElementById('devSpeakers');
  let audioOnHeadphones = true;

  if (btnTriggerSoundSwap && devHeadphones && devSpeakers) {
    btnTriggerSoundSwap.addEventListener('click', () => {
      audioOnHeadphones = !audioOnHeadphones;
      if (audioOnHeadphones) {
        devHeadphones.classList.add('active');
        devSpeakers.classList.remove('active');
        devHeadphones.querySelector('.dev-status').textContent = 'Active Playback Device';
        devSpeakers.querySelector('.dev-status').textContent = 'Standby';
      } else {
        devSpeakers.classList.add('active');
        devHeadphones.classList.remove('active');
        devSpeakers.querySelector('.dev-status').textContent = 'Active Playback Device';
        devHeadphones.querySelector('.dev-status').textContent = 'Standby';
      }
    });
  }

  // D. Hyper Key Office Neutralizer Simulation
  const btnTestHyper = document.getElementById('btnTestHyper');
  const chordResult = document.querySelector('.chord-result');

  if (btnTestHyper && chordResult) {
    btnTestHyper.addEventListener('click', () => {
      chordResult.style.color = '#D9822B';
      chordResult.textContent = '⚡ Protocol check intercepted: ms-officeapp: blocked. Key free!';
      setTimeout(() => {
        chordResult.style.color = '#52B788';
        chordResult.textContent = '→ No browser opens. Handled directly by Mello.';
      }, 1800);
  // 4. Ambient Auto-Looping Feature Demos (visual loops)
  let autoLoopTimer = null;
  const startAutoLoops = () => {
    autoLoopTimer = setInterval(() => {
      const activePanel = document.querySelector('.showcase-panel.active');
      if (!activePanel) return;

      if (activePanel.id === 'panel-snapping' && btnTriggerSnap) {
        btnTriggerSnap.click();
      } else if (activePanel.id === 'panel-quicknote' && btnToggleNotepad) {
        btnToggleNotepad.click();
      } else if (activePanel.id === 'panel-soundswap' && btnTriggerSoundSwap) {
        btnTriggerSoundSwap.click();
      }
    }, 3800);
  };

  startAutoLoops();

  // Pause ambient loop on user hover/interaction so they can control it intentionally
  const showcaseContainer = document.querySelector('.showcase-container');
  if (showcaseContainer) {
    showcaseContainer.addEventListener('mouseenter', () => clearInterval(autoLoopTimer));
    showcaseContainer.addEventListener('mouseleave', () => startAutoLoops());
  }

  // 5. Audio Walkthrough Player
  const btnAudio = document.getElementById('btnAudioWalkthrough');
  const audioElement = document.getElementById('walkthroughAudio');

  if (btnAudio && audioElement) {
    btnAudio.addEventListener('click', () => {
      if (audioElement.paused) {
        audioElement.play().then(() => {
          btnAudio.classList.add('playing');
          btnAudio.querySelector('.audio-text').textContent = 'Playing Walkthrough';
        }).catch(() => {});
      } else {
        audioElement.pause();
        btnAudio.classList.remove('playing');
        btnAudio.querySelector('.audio-text').textContent = 'Listen: Walkthrough (60s)';
      }
    });

    audioElement.addEventListener('ended', () => {
      btnAudio.classList.remove('playing');
      btnAudio.querySelector('.audio-text').textContent = 'Listen: Walkthrough (60s)';
    });
  }
});
