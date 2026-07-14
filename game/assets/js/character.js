// ============================================================
// ZOMBIE NEON — Reusable Main Character module
// ------------------------------------------------------------
// Builds the exact same neon runner character (body, head, two-
// segment limbs with knee/elbow joints, chest core light, back
// thruster pack) used in Level 1. Any future level should include
// this same file and call ZombieCharacter.create(scene) so the
// character always looks and rigs identically across levels.
//
// Usage:
//   var char = ZombieCharacter.create(scene);
//   // char.player  -> THREE.Group added to the scene already
//   // char.limbs   -> { lLeg, rLeg, lArm, rArm,
//   //                    lLegJoint, rLegJoint, lArmJoint, rArmJoint }
//   // Drive the run/jump animation each frame from the calling
//   // level's own game loop using char.limbs (see index.html's
//   // animate() for a reference implementation of the gait).
// ============================================================
(function () {

  function create(scene) {
    var player = new THREE.Group();
    var limbs = {};

    var matShirt = new THREE.MeshLambertMaterial({color: 0x00ffff});
    var matJacket = new THREE.MeshLambertMaterial({color: 0x0a2a33});
    var matNeon = new THREE.MeshBasicMaterial({color: 0x00ffff});
    var matVisor = new THREE.MeshBasicMaterial({color: 0xff0055});
    var matBoot = new THREE.MeshBasicMaterial({color: 0xff0055});
    var matSkin = new THREE.MeshLambertMaterial({color: 0xffccaa});

    // Torso with layered jacket + chest neon strip for extra detail
    var body = new THREE.Mesh(new THREE.BoxGeometry(0.85, 1.4, 0.55), matJacket); body.position.y = 2.2;
    var chestStrip = new THREE.Mesh(new THREE.BoxGeometry(0.15, 1.2, 0.02), matNeon); chestStrip.position.set(0, 0, 0.29);
    body.add(chestStrip);
    var collar = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.15, 0.6), matShirt); collar.position.y = 0.75; body.add(collar);
    var lShoulder = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.25, 0.5), matNeon); lShoulder.position.set(-0.55, 0.68, 0); body.add(lShoulder);
    var rShoulder = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.25, 0.5), matNeon); rShoulder.position.set(0.55, 0.68, 0); body.add(rShoulder);
    var belt = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.2, 0.6), new THREE.MeshBasicMaterial({color:0xff0055})); belt.position.y = -0.7; body.add(belt);

    // Head with visor + faceplate detailing
    var head = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.6, 0.6), matSkin); head.position.y = 3.3;
    var visor = new THREE.Mesh(new THREE.BoxGeometry(0.52, 0.15, 0.35), matVisor); visor.position.set(0, 0.05, -0.15); head.add(visor);
    var mask = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.62, 0.15), matJacket); mask.position.set(0, -0.28, -0.05); head.add(mask);
    var antenna = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.4), matNeon); antenna.position.set(0.2, 0.5, 0);
    var antennaTip = new THREE.Mesh(new THREE.SphereGeometry(0.06), matVisor); antennaTip.position.y = 0.22; antenna.add(antennaTip);
    head.add(antenna);

    // Two-segment limb: upper piece + a knee/elbow joint group + lower piece + glowing end cap.
    // The joint group is meant to be animated by the calling level's game loop for a natural bend
    // instead of a rigid rotating box.
    function mkLimb(x, y, upperLen, lowerLen, mat, jointMat, glowMat, padMat) {
      var g = new THREE.Group();
      var upper = new THREE.Mesh(new THREE.BoxGeometry(0.36, upperLen, 0.36), mat); upper.position.y = -upperLen/2;
      var pad = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.16, 0.42), padMat); pad.position.y = -upperLen + 0.05;
      upper.add(pad);
      var joint = new THREE.Group(); joint.position.y = -upperLen;
      var lower = new THREE.Mesh(new THREE.BoxGeometry(0.3, lowerLen, 0.3), jointMat); lower.position.y = -lowerLen/2;
      var cap = new THREE.Mesh(new THREE.BoxGeometry(0.36, 0.16, 0.36), glowMat); cap.position.y = -lowerLen;
      lower.add(cap);
      joint.add(lower);
      g.add(upper); upper.add(joint);
      g.position.set(x, y, 0);
      g.userData.joint = joint;
      return g;
    }
    var matLimbDark = new THREE.MeshLambertMaterial({color:0x1a1a22});
    limbs.lLeg = mkLimb(-0.25, 1.5, 0.75, 0.75, matLimbDark, matLimbDark, matBoot, matNeon);
    limbs.rLeg = mkLimb(0.25, 1.5, 0.75, 0.75, matLimbDark, matLimbDark, matBoot, matNeon);
    limbs.lArm = mkLimb(-0.7, 2.8, 0.7, 0.7, matJacket, matJacket, matNeon, matNeon);
    limbs.rArm = mkLimb(0.7, 2.8, 0.7, 0.7, matJacket, matJacket, matNeon, matNeon);
    limbs.lLegJoint = limbs.lLeg.userData.joint;
    limbs.rLegJoint = limbs.rLeg.userData.joint;
    limbs.lArmJoint = limbs.lArm.userData.joint;
    limbs.rArmJoint = limbs.rArm.userData.joint;

    // Extra character detailing: chest core light + back thruster pack tying into the jump effect
    var chestCore = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.06, 12), new THREE.MeshBasicMaterial({color: 0x00ffff}));
    chestCore.rotation.x = Math.PI/2; chestCore.position.set(0, 0.15, 0.29); body.add(chestCore);
    var pack = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.7, 0.25), matJacket); pack.position.set(0, 0.05, -0.35); body.add(pack);
    var thrusterL = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.18, 8), matNeon); thrusterL.position.set(-0.15, -0.35, -0.37); pack.add(thrusterL);
    var thrusterR = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.18, 8), matNeon); thrusterR.position.set(0.15, -0.35, -0.37); pack.add(thrusterR);

    player.add(body, head, limbs.lLeg, limbs.rLeg, limbs.lArm, limbs.rArm);
    if (scene) scene.add(player);

    return { player: player, limbs: limbs };
  }

  window.ZombieCharacter = { create: create };

})();
