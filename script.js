(function () {
  'use strict';

  var TRACE_LINE_URL = 'https://lin.ee/Y4Hz0uT';
  var TRACE_INSTAGRAM_URL = 'https://www.instagram.com/trace_saga?igsh=OHkyYmZuZ2JwMmVj&utm_source=qr';

  var header = document.getElementById('header');
  var menuBtn = document.getElementById('menuBtn');
  var nav = document.getElementById('nav');
  var floatLine = document.getElementById('floatLine');
  var navLinks = document.querySelectorAll('.nav__link[data-nav]');
  var revealElements = document.querySelectorAll('.reveal');
  var lineLinks = document.querySelectorAll('.js-line-reserve');
  var instagramLinks = document.querySelectorAll('.js-instagram');

  var scrollThreshold = 20;
  var lastScrollY = 0;
  var isMenuOpen = false;
  var prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function handleScroll() {
    var currentScrollY = window.scrollY;

    if (header) {
      header.classList.toggle('is-scrolled', currentScrollY > scrollThreshold);

      if (!isMenuOpen && currentScrollY > 400) {
        header.classList.toggle('is-hidden', currentScrollY > lastScrollY && currentScrollY > 500);
      } else {
        header.classList.remove('is-hidden');
      }
    }

    if (floatLine) {
      var footer = document.querySelector('.footer');
      var hideFloat = false;

      if (footer) {
        hideFloat = footer.getBoundingClientRect().top < window.innerHeight;
      }

      floatLine.classList.toggle('is-hidden', hideFloat);
    }

    lastScrollY = currentScrollY;
  }

  function openMenu() {
    isMenuOpen = true;
    menuBtn.classList.add('is-active');
    nav.classList.add('is-open');
    menuBtn.setAttribute('aria-expanded', 'true');
    menuBtn.setAttribute('aria-label', 'メニューを閉じる');
    document.body.style.overflow = 'hidden';
    header.classList.remove('is-hidden');
  }

  function closeMenu() {
    isMenuOpen = false;
    menuBtn.classList.remove('is-active');
    nav.classList.remove('is-open');
    menuBtn.setAttribute('aria-expanded', 'false');
    menuBtn.setAttribute('aria-label', 'メニューを開く');
    document.body.style.overflow = '';
  }

  function toggleMenu() {
    if (isMenuOpen) {
      closeMenu();
    } else {
      openMenu();
    }
  }

  function initMenu() {
    if (!menuBtn || !nav) return;

    menuBtn.addEventListener('click', toggleMenu);

    navLinks.forEach(function (link) {
      link.addEventListener('click', closeMenu);
    });

    document.querySelectorAll('.nav__reserve').forEach(function (link) {
      link.addEventListener('click', closeMenu);
    });

    window.addEventListener('resize', function () {
      if (window.innerWidth >= 768 && isMenuOpen) {
        closeMenu();
      }
    });
  }

  function initExternalLinks() {
    lineLinks.forEach(function (link) {
      link.setAttribute('href', TRACE_LINE_URL);
    });

    instagramLinks.forEach(function (link) {
      link.setAttribute('href', TRACE_INSTAGRAM_URL);
    });
  }

  function initScrollReveal() {
    if (!revealElements.length) return;

    if (!('IntersectionObserver' in window)) {
      revealElements.forEach(function (el) {
        el.classList.add('is-visible');
      });
      return;
    }

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            entry.target.style.willChange = 'auto';
            observer.unobserve(entry.target);
          }
        });
      },
      {
        root: null,
        rootMargin: '0px 0px -8% 0px',
        threshold: 0.08
      }
    );

    revealElements.forEach(function (el) {
      if (!el.closest('.hero')) {
        if (!prefersReducedMotion) {
          el.style.willChange = 'transform, opacity';
        }
        observer.observe(el);
      }
    });
  }

  function initHeroReveal() {
    var heroReveals = document.querySelectorAll('.hero .reveal');

    if (prefersReducedMotion) {
      heroReveals.forEach(function (el) {
        el.classList.add('is-visible');
      });
      return;
    }

    heroReveals.forEach(function (el, index) {
      if (!prefersReducedMotion) {
        el.style.willChange = 'transform, opacity';
      }
      setTimeout(function () {
        el.classList.add('is-visible');
        el.style.willChange = 'auto';
      }, 120 + index * 75);
    });
  }

  function initStaggerReveal() {
    var groups = document.querySelectorAll(
      '.feature__grid, .flow__steps, .program__grid, .result__grid, .equipment__grid, .price__grid, .voice__grid, .faq__list'
    );

    groups.forEach(function (group) {
      var items = group.querySelectorAll('.reveal');
      items.forEach(function (item, index) {
        item.style.transitionDelay = (index * 0.06) + 's';
      });
    });
  }

  function initActiveNav() {
    if (!('IntersectionObserver' in window) || !navLinks.length) return;

    var sections = [];

    navLinks.forEach(function (link) {
      var id = link.getAttribute('data-nav');
      var section = document.getElementById(id);
      if (section) sections.push({ id: id, el: section });
    });

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            navLinks.forEach(function (link) {
              link.classList.toggle('is-active', link.getAttribute('data-nav') === entry.target.id);
            });
          }
        });
      },
      {
        root: null,
        rootMargin: '-40% 0px -50% 0px',
        threshold: 0
      }
    );

    sections.forEach(function (section) {
      observer.observe(section.el);
    });
  }

  function getHashTarget(hash) {
    if (!hash || hash === '#') return null;

    var id = hash.charAt(0) === '#' ? hash.slice(1) : hash;
    return document.getElementById(id);
  }

  function scrollToTarget(target) {
    if (!target) return;

    var headerOffset = header ? header.offsetHeight : 0;
    var targetPosition = target.getBoundingClientRect().top + window.scrollY - headerOffset;

    window.scrollTo({
      top: Math.max(0, targetPosition),
      behavior: prefersReducedMotion ? 'auto' : 'smooth'
    });
  }

  function scrollToHash(hash, retries) {
    var target = getHashTarget(hash);
    if (!target) {
      if (retries > 0) {
        window.setTimeout(function () {
          scrollToHash(hash, retries - 1);
        }, 150);
      }
      return;
    }

    scrollToTarget(target);
  }

  function initSmoothAnchor() {
    document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
      anchor.addEventListener('click', function (event) {
        var targetId = anchor.getAttribute('href');
        var target = getHashTarget(targetId);
        if (!target) return;

        event.preventDefault();
        if (targetId && targetId !== '#') {
          history.pushState(null, '', targetId);
        }
        scrollToTarget(target);
        closeMenu();
      });
    });
  }

  function initHashScroll() {
    if ('scrollRestoration' in history) {
      history.scrollRestoration = 'manual';
    }

    if (!window.location.hash) return;

    window.scrollTo(0, 0);
    scrollToHash(window.location.hash, 8);
  }

  function initFaqAccordion() {
    var items = document.querySelectorAll('.faq-item');

    items.forEach(function (item) {
      var trigger = item.querySelector('.faq-item__trigger');
      var panel = item.querySelector('.faq-item__panel');

      if (!trigger || !panel) return;

      trigger.addEventListener('click', function () {
        var isOpen = item.classList.toggle('is-open');
        trigger.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
        panel.setAttribute('aria-hidden', isOpen ? 'false' : 'true');
      });
    });
  }

  function init() {
    initExternalLinks();
    handleScroll();
    window.addEventListener('scroll', handleScroll, { passive: true });
    initMenu();
    initStaggerReveal();
    initHeroReveal();
    initScrollReveal();
    initActiveNav();
    initSmoothAnchor();
    initHashScroll();
    initFaqAccordion();

    window.addEventListener('hashchange', function () {
      scrollToHash(window.location.hash, 3);
    });

    window.addEventListener('load', function () {
      if (window.location.hash) {
        scrollToHash(window.location.hash, 5);
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
