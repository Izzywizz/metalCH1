import PlaygroundSupport
import MetalKit

guard let device = MTLCreateSystemDefaultDevice() else { //access GPU
    fatalError("GPU is not supported")
}

let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)

view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)


//1 - manage memory for the mesh data
let allocator = MTKMeshBufferAllocator(device: device)
//2 - create spehere using metal I/O with specified size and vertex info
let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75], segments: [100, 100], inwardNormals: false, geometryType: .triangles, allocator: allocator)
//3 - convert metal I/O mesh to a mesh that metalKit mesh
let mesh = try MTKMesh(mesh: mdlMesh, device: device)

guard let commandQueue = device.makeCommandQueue() else { fatalError("Could not create a command queue") }

