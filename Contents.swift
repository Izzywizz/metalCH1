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

let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {

float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
    return vertex_in.position;
}

fragment float4 fragment_main() {
    return float4(1,0,0,1);
}
"""

//(above)creating shader func in c++, these programs run directly on the GPU: vertex_main - manipulate vertex positions, fragment_main - pixel colour
//(below) setup metal lib that contains the 2 func above
let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

// recall that a descriptor is needed to control the piepline state; so we setup the correct shader funcs and a vertex descriptor.
// the vertex descriptor tells the metal buffer how the vertex should be laid out, metal I/O already had one ready for us
let descriptor = MTLRenderPipelineDescriptor()
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
descriptor.vertexFunction = vertexFunction
descriptor.fragmentFunction = fragmentFunction
descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

//pipelinState takes up processing time, so think one-time setup! Though you may need multiple pipeleines for different shader funcs/ vertex layouts
let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)

//rendering - per frame
//1 - cmd buffer, stores all cmds that you'll ask of the GPU
guard let commmandBuffer = commandQueue.makeCommandBuffer(),
//2 - this view render pass descriptor holds data on rederner destinations known as attachments.
    // each attachemnt has info on which texture to store and whether to keep it thrrugh the piepline process
    // we use this pass descriptor to create our render encoder
let descriptor = view.currentRenderPassDescriptor,
//3 - render encoder, holds all the neccasry info we send to the GPU
let renderEncoder = commmandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
else { fatalError() }

renderEncoder.setRenderPipelineState(pipelineState)
//verticles info is stored in that sphere mesh we made earlier, we pass this LIST on to renderEncoder
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
//offset and index are used to locate within the buffer where in the vertex info starts

//remember that mesh is made up of submeshes, different material types, you can render one vertex multiple times
// this sphere only has 1 submesh

guard let submesh = mesh.submeshes.first else { fatalError() }

//drawing the shape
// telling the GPU to render the vertex buffer consisting of triangles placed in the corect order via the sibmesh index info
//this is acutally NOT the rendering, we need to pass ALL of the command buffers commands on
renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)

//1 - no more draw calls
renderEncoder.endEncoding()
//2 - MTKView is bacaked by Core Animation metal layer, making it possible to draw texts via metal
guard let drawable = view.currentDrawable else { fatalError() }
//3 - command buffer presents the MTKView drawable and commits this to the GPU
commmandBuffer.present(drawable)
commmandBuffer.commit()

PlaygroundPage.current.liveView = view
